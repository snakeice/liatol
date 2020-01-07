unit System.CSV;

interface

uses
  System.Generics.Collections, System.Classes, System.Rtti, System.SysUtils;

type
  TBufferedReader = class;

  TLineInfo = record
    Size: Int64;
    Line: Int64;
    Data: string;
    Buffer: TBufferedReader;
    function ToString: string;
    Function ReadText: string;
  end;

  TBufferedReader = class
  private
    FFile: TextFile;

    BufferSize: Integer;
    LinesIndex: array of TLineInfo;

    procedure LoadAllLines;
    procedure WriteLine(AData: string; ALine: Int64);

    function EnsureLineIndex(ALine: Int64): Boolean;
  public
    function PageSize: Integer;
    function PageCount: Int64;
    function ReadLine(ALine: Int64): TLineInfo;

    constructor Create(AFileName: string; ABufferSize: Integer = -1);
    destructor Destroy; override;

  end;

  TCSVField = record
    var raw: string;
    function GetBoolean: Boolean;
    function GetDateTime: TDateTime;
    function GetFloat: Double;
    function GetInt64: Int64;
    function GetInteger: Integer;
    function GetString: string;
    procedure SetBoolean(const Value: Boolean);
    procedure SetDateTime(const Value: TDateTime);
    procedure SetFloat(const Value: Double);
    procedure SetInt64(const Value: Int64);
    procedure SetInteger(const Value: Integer);
    procedure SetString(const Value: string);

    property AsString: string read GetString write SetString;
    property AsFloat: Double read GetFloat write SetFloat;
    property AsInteger: Integer read GetInteger write SetInteger;
    property AsInt64: Int64 read GetInt64 write SetInt64;
    property AsBoolean: Boolean read GetBoolean write SetBoolean;
    property AsDateTime: TDateTime read GetDateTime write SetDateTime;
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

function MakeField(AValue: string): TCSVField;
begin
  Result.raw := AValue;
end;

function MakeLineInfo(AData: string; ALine: Int64; AReader: TBufferedReader): TLineInfo;
begin
  Result.Line := ALine;
  Result.Data := AData;
  Result.Buffer := AReader;
  Result.Size := Length(AData);
end;

{ TCSVFile }

constructor TCSVFile.Create(AFileName: string; ADelimiter: Char; ABufferSize: Integer);
begin
  Assert(ABufferSize >= 1024, 'Buffer need >= 1024 B');
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
begin
  if not FileExists(AFileName) then
    raise Exception.Create('File not exists');
  AssignFile(FFile, AFileName);
  {$I-}
  Append(FFile);
  {$I+}
end;

destructor TBufferedReader.Destroy;
begin
  inherited;
end;

function TBufferedReader.EnsureLineIndex(ALine: Int64): Boolean;
var
  LData: string;
  LLineNo: Int64;
begin
  Result := True;
  if Length(LinesIndex) >= ALine then
    Exit;

  while (Length(LinesIndex) < ALine) and not Eof(Self.FFile) do
  begin
    Readln(FFile, LData);
    LLineNo := Length(LinesIndex) + 1;

    SetLength(LinesIndex, Length(LinesIndex) + 1);
    LinesIndex[High(LinesIndex)] := MakeLineInfo(LData, LLineNo, Self);
    Result := True;
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

function TBufferedReader.ReadLine(ALine: Int64): TLineInfo;
begin
  EnsureLineIndex(ALine);

  Result := LinesIndex[ALine];
end;

procedure TBufferedReader.WriteLine(AData: string; ALine: Int64);
begin
  Writeln(FFile, AData, ALine);
end;

{ TLineInfo }

function TLineInfo.ReadText: string;
begin
  Result := Self.Data;
end;

function TLineInfo.ToString: string;


begin
  Result :=
    '{' + sLineBreak +
    '  "Size": ' + Self.Size.ToString + ',' + sLineBreak +
    '  "Line": ' + Self.Line.ToString + ',' + sLineBreak +
    '  "Data": ' + Self.Data + sLineBreak +
    '}';
end;

end.
