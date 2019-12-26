unit System.CSV;

interface

uses
  System.Generics.Collections, System.Classes, System.Rtti, System.SysUtils;

type
  TBufferedReader = class;

  TLineInfo = record
    Page: Int64;
    EndPage: Int64;
    EndPosition: Int64;
    Position: Int64;
    Size: Int64;
    Bytes: TBytes;
    Reader: TBufferedReader;
    function ToString: string;
    Function ReadText: string;
  end;

  TBufferedReader = class
  private
    FFile: TFileStream;

    BufferSize: Integer;
    RawBuffer: array of TBytes;
    LinesIndex: array of TLineInfo;

    BOMLength: Integer;
    FEncoding: TEncoding;

    procedure LoadAllBuffer;
    procedure LoadAllLines;

    function EnsureLineIndex(ALine: Int64): Boolean;
    procedure EnsureBufferIndex(ABufferIndex: Int64);
    function DefaultBufferSize: Integer;
  public
    function Size: Int64;
    function PageSize: Integer;
    function PageCount: Int64;
    function ReadBufferPage(APage: Int64): TBytes;
    function ReadLine(ALine: Int64): TLineInfo;

    constructor Create(AFileName: string; ABufferSize: Integer = -1);
    destructor Destroy; override;

  end;

  TCSVField = record
  var
    Value: string;
    function AsString: string;
    function AsFloat: Double;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsBoolean: Boolean;
    function AsDateTime: TDateTime;
  end;

  TCSVFile = class
  private
    FBuffer: TBufferedReader;
    FIndex: Int64;
    FDelimiter: Char;
    FFieldIndex: TDictionary<string, Integer>;
    FCurrentLine: string;
    FCurrentLineInfo: TLineInfo;

    constructor Create(AFileName: string; ADelimiter: Char; ABufferSize: Integer);
    procedure ReadLine(ALine: Int64);
    function GetValue(Index: String): TCSVField;
    function GetFields: TArray<String>;
    function GetLine(Index: Int64): TCSVFile;
  public
    property Value[Index: String]: TCSVField read GetValue; default;
    property Line[Index: Int64]: TCSVFile read GetLine;
    property CurrentIndex: Int64 read FIndex;
    property CurrentLine: string read FCurrentLine;
    property CurrentLineInfo: TLineInfo read FCurrentLineInfo;
    function Size: Int64;
    function HasField(AField: string): Boolean;
    property Fields: TArray<String> read GetFields;
    procedure Initialize;
  public
    destructor Destroy; override;
  end;

function ReadCSV(AFileName: string): TCSVFile; overload;
function ReadCSV(AFileName: string; ADelimiter: Char): TCSVFile; overload;
function ReadCSV(AFileName: string; ADelimiter: Char; ABufferSize: Integer): TCSVFile; overload;

implementation

uses
  System.IOUtils, System.Math;

Function MakeField(AValue: string): TCSVField;
begin
  Result.Value := AValue;
end;

{ TCSVFile }

constructor TCSVFile.Create(AFileName: string; ADelimiter: Char; ABufferSize: Integer);
begin
  Assert(ABufferSize >= 32, 'Buffer need >= 32');
  FBuffer := TBufferedReader.Create(AFileName, ABufferSize);
  FDelimiter := ADelimiter;

  FCurrentLine := '';
  FIndex := 1;
  FFieldIndex := TDictionary<string, Integer>.Create;

  Initialize;
end;

destructor TCSVFile.Destroy;
begin
  FFieldIndex.Free;
  FBuffer.Free;
  inherited;
end;

function TCSVFile.GetFields: TArray<String>;
begin
  Result := FFieldIndex.Keys.ToArray;
end;

function TCSVFile.GetLine(Index: Int64): TCSVFile;
begin
  ReadLine(Index + 1);
  Result := Self;
end;

function TCSVFile.GetValue(Index: String): TCSVField;
begin
  if not HasField(Index) then
    raise Exception.Create('Field ' + Index + ' not found');
  if not FCurrentLine.IsEmpty then
    Result := MakeField(FCurrentLine.Split(FDelimiter)[FFieldIndex[Index]]);
end;

function TCSVFile.HasField(AField: string): Boolean;
begin
  Result := FFieldIndex.ContainsKey(AField);
end;

procedure TCSVFile.Initialize;
var
  LFields: TArray<string>;
  LIndex: Integer;
begin
  LFields := FBuffer.ReadLine(1).ReadText.Split(FDelimiter);
  for LIndex := 0 to Length(LFields) - 1 do
     FFieldIndex.Add(LFields[LIndex], LIndex);
end;

procedure TCSVFile.ReadLine(ALine: Int64);
begin
  if FIndex = ALine then
    Exit;

  FIndex := ALine;
  FCurrentLineInfo := FBuffer.ReadLine(FIndex);
  FCurrentLine := FCurrentLineInfo.ReadText;
end;

function TCSVFile.Size: Int64;
begin
  Result := FBuffer.PageCount;
end;

function ReadCSV(AFileName: string; ADelimiter: Char; ABufferSize: Integer): TCSVFile; overload;
begin
  Result := TCSVFile.Create(AFileName, ADelimiter, ABufferSize);
end;

function ReadCSV(AFileName: string; ADelimiter: Char): TCSVFile;
begin
  Result := ReadCSV(AFileName, ADelimiter, 1024);
end;

function ReadCSV(AFileName: string): TCSVFile;
begin
  Result := ReadCSV(AFileName, ';');
end;

{ TBufferedReader }

constructor TBufferedReader.Create(AFileName: string; ABufferSize: Integer);
var
  LPages: Int64;
begin
  if not FileExists(AFileName) then
    raise Exception.Create('File not exists');

  BOMLength := -1;
  BufferSize := ABufferSize;
  FFile := TFileStream.Create(AFileName, fmShareDenyNone);
  FFile.Position := 0;

  LPages := Ceil(FFile.Size / ABufferSize);

  SetLength(RawBuffer, LPages);

  LoadAllBuffer;
end;

function TBufferedReader.DefaultBufferSize: Integer;
const
  PERCENT = 0.0003;
var
 LKb: Int64;
 LResult: Double;
begin
  LKb := Round(FFile.Size / 1024);
  LResult := LKb * PERCENT;

  Result := 1024;
end;

destructor TBufferedReader.Destroy;
begin
  FFile.Free;
  inherited;
end;

procedure TBufferedReader.EnsureBufferIndex(ABufferIndex: Int64);
begin
  //
end;

function TBufferedReader.EnsureLineIndex(ALine: Int64): Boolean;
var
  LCurrentPage: Int64;
  LBufferPosition: Integer;
  LByte: Byte;
  LLineSize: Integer;
  LCurrentPageSize: Integer;

  LLastLine, LCurrentLine: TLineInfo;
begin
  Result := True;
  if Length(LinesIndex) >= ALine then
    Exit;

  while Length(LinesIndex) < ALine do
  begin
    if Length(LinesIndex) = 0 then
    begin
      LLastLine.Position := 0;
      LLastLine.Page := 0;
      LCurrentLine.Page := 0;
      LCurrentLine.Position := 0;
    end
    else
    begin
      LLastLine := LinesIndex[High(LinesIndex)];
      if Length(RawBuffer) = LLastLine.EndPage then
        Exit;

      if (LLastLine.EndPosition + 1 > Length(RawBuffer[LLastLine.EndPage]) - 1) then
      begin
        LCurrentLine.Page := LLastLine.EndPage + 1;
        LCurrentLine.Position := 0;
        if (Length(RawBuffer) - 1) < LCurrentLine.EndPage then
          Exit(False);
      end
      else
      begin
        LCurrentLine.Page := LLastLine.EndPage;
        LCurrentLine.Position := LLastLine.EndPosition + 1;
      end;
    end;

    LCurrentPage := LCurrentLine.Page;
    LBufferPosition := LCurrentLine.Position;
    LLineSize := 0;
    LCurrentPageSize := Length(RawBuffer[LCurrentPage]);
    SetLength(LCurrentLine.Bytes, 0);
    while True do
    begin
      EnsureBufferIndex(LCurrentPage);
      LByte := RawBuffer[LCurrentPage][LBufferPosition];
      if LByte = 13 then
        Break;

      if LByte <> 10 then
      begin
        SetLength(LCurrentLine.Bytes, Length(LCurrentLine.Bytes) + 1);
        LCurrentLine.Bytes[High(LCurrentLine.Bytes)] := LByte;
      end;

      Inc(LLineSize);
      Inc(LBufferPosition);
      if LBufferPosition > LCurrentPageSize - 1 then
      begin
        Inc(LCurrentPage);
        LBufferPosition := 0;

        if LCurrentPage > Length(RawBuffer) - 1 then
          Break;

        LCurrentPageSize := Length(RawBuffer[LCurrentPage]);
      end;
    end;
    LCurrentLine.EndPage := LCurrentPage;
    LCurrentLine.EndPosition := LBufferPosition;
    LCurrentLine.Size := LLineSize;
    SetLength(LinesIndex, Length(LinesIndex) + 1);
    LCurrentLine.Reader := Self;
    LinesIndex[High(LinesIndex)] := LCurrentLine;
    Result := True;
  end;
end;

procedure TBufferedReader.LoadAllBuffer;
var
  LIndex: Integer;
  LBufferSize: Integer;
begin
  for LIndex := 0 to Length(RawBuffer) - 1 do
  begin
    if (FFile.Position + BufferSize) > FFile.Size then
      LBufferSize := FFile.Size - FFile.Position
    else
      LBufferSize := BufferSize;

    SetLength(RawBuffer[LIndex], LBufferSize);

    FFile.ReadBuffer(RawBuffer[LIndex], LBufferSize);
  end;
end;

procedure TBufferedReader.LoadAllLines;
begin
  EnsureLineIndex(Int64.MaxValue);
end;

function TBufferedReader.PageCount: Int64;
begin
  LoadAllLines;
  Result := Length(LinesIndex) - 1;
end;

function TBufferedReader.PageSize: Integer;
begin
  Result := BufferSize;
end;

function TBufferedReader.ReadBufferPage(APage: Int64): TBytes;
begin
  Result := RawBuffer[APage];
end;

function TBufferedReader.ReadLine(ALine: Int64): TLineInfo;
begin
  EnsureLineIndex(ALine);

  Result := LinesIndex[ALine - 1];
end;

function TBufferedReader.Size: Int64;
begin
  Result := FFile.Size;
end;

{ TCSVField }

function TCSVField.AsBoolean: Boolean;
begin
  Result := StrToBoolDef(Value, False);
end;

function TCSVField.AsDateTime: TDateTime;
begin
  Result := StrToDateTime(Value);
end;

function TCSVField.AsFloat: Double;
begin
  Result := StrToFloat(Value);
end;

function TCSVField.AsInt64: Int64;
begin
  Result := StrToInt64(Value);
end;

function TCSVField.AsInteger: Integer;
begin
  Result := StrToInt(Value);
end;

function TCSVField.AsString: string;
begin
  Result := Value;
end;

{ TLineInfo }

function TLineInfo.ReadText: string;
var
  LBuffer: TBytes;
begin
  Result := EmptyStr;

  LBuffer := Self.Bytes;

  if Reader.BOMLength = -1 then
    Reader.BOMLength := TEncoding.GetBufferEncoding(LBuffer, Reader.FEncoding);

  Result := Reader.FEncoding.GetString(LBuffer, Reader.BOMLength, Length(LBuffer) - Reader.BOMLength);
end;

function TLineInfo.ToString: string;
  function GetBytesJsonArray: string;
  var
    LIndex: Integer;
    LHigh: Integer;
  begin
    Result := '[';
    LHigh := High(Self.Bytes);
    for LIndex := Low(Self.Bytes) to LHigh do
    begin
      Result := Result + Self.Bytes[LIndex].ToString;
      if LIndex <> LHigh then
        Result := Result + ', ';
    end;
    Result := Result + ']';
  end;
  
begin
  Result :=
    '{' + sLineBreak +
    '  "Page": ' + Self.Page.ToString + ',' + sLineBreak +
    '  "EndPage": ' + Self.EndPage.ToString + ',' + sLineBreak +
    '  "EndPosition": ' + Self.EndPosition.ToString + ',' + sLineBreak +
    '  "Position": ' + Self.Position.ToString + ',' + sLineBreak +
    '  "Size": ' + Self.Size.ToString + ',' + sLineBreak +
    '  "Bytes": ' + GetBytesJsonArray + sLineBreak +
    '}';
end;

end.
