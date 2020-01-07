unit Tests;

interface

uses
  System.CSV, Classes, System.SysUtils;

procedure RunTests();

implementation

uses
  Winapi.Windows;

var
  startTime64, endTime64, frequency64: Int64;
  elapsedSeconds: single;

procedure StartTime();
begin
  QueryPerformanceFrequency(frequency64);
  QueryPerformanceCounter(startTime64);
end;

procedure EndTime();
begin
  QueryPerformanceCounter(endTime64);
  elapsedSeconds := (endTime64 - startTime64) / frequency64;
  Writeln(Format('Time: %fs', [elapsedSeconds]));
end;

procedure ReadWriteAll();
var
  LCsv: TCSVFile;
  LIndex: Int64;
  StringList: TStringList;
  Line: string;
  LField: string;
  LBufferSize: Integer;
begin
  LBufferSize := StrToIntDef(ParamStr(1), 256);
  Writeln(Format('Buffer size %d', [LBufferSize]));
  StringList := TStringList.Create;
  try
    LCsv := ReadCSV('../../avaliacao.csv', ';', LBufferSize);
    try
      for LIndex := 1 to LCsv.Size do
      begin
        Line := '';
        for LField in LCsv.Fields do
        begin
          Line := Line + LCsv.Line[LIndex][LField].AsString + ';';
        end;

        // StringList.Add(LCsv.CurrentLineInfo.ToString);
        // StringList.Add(LCsv.CurrentLine);
        StringList.Add(Line.Substring(0, Line.Length - 1));
      end;
    finally
      LCsv.Free;
    end;
    StringList.SaveToFile(Format('out-%d.txt', [LBufferSize]));
  finally
    StringList.Free;
  end;
end;

procedure ReadSize;
  procedure Run(ASize: Int64);
  var
    LCsv: TCSVFile;
    LLine: Integer;
  begin
    Writeln(Format(sLineBreak + 'Running read size with buff size: %d', [ASize]));
    StartTime;
    LCsv := ReadCSV('../../avaliacao1m.csv', ';', ASize);
    try
      Writeln(Format('Size %d', [LCsv.Size]));
      Randomize;
//      LLine := Random(LCsv.Size);
      LLine := LCsv.Size;
      Writeln(Format('Line %d', [LLine]));
      Writeln('Line info:' + sLineBreak + LCsv.Line[LLine].CurrentLineInfo.ToString);
      Writeln('Last line: ' + LCsv.Line[LLine].CurrentLine);
      Writeln('Avaliação: ' + LCsv.Line[LLine]['AVALIACAO'].AsString);
      EndTime;
    finally
      LCsv.Free;
    end;
  end;

begin
  Run(1024);
  Run(2048);
  Run(4096);
  Run(8192);
  Run(16384);
  Run(32768);
  Run(65536);
  Run(131072);
  Run(262144);
  Run(524288);
  Run(1048576);
  Run(2097152);
  Run(4194304);
  Run(8388608);
  Run(1024000000);
end;

procedure ReadRandom();
var
  LSizeCSV: Int64;

  procedure Run();
  var
    LCsv: TCSVFile;
    LLine: Integer;
  begin
    Writeln(sLineBreak);
    Writeln(sLineBreak);
    Writeln(sLineBreak);

    StartTime;
    LCsv := ReadCSV('../../1m.csv', ';', 1048576);
    try
      if LSizeCSV = -1 then
        LSizeCSV := LCsv.Size;

      Randomize;
      LLine := Random(LSizeCSV);
      Writeln(Format('Line %d', [LLine]));
      Writeln('Line info:' + sLineBreak + LCsv.Line[LLine].CurrentLineInfo.ToString);
      Writeln('Last line: ' + LCsv.Line[LLine].CurrentLine);
      EndTime;
    finally
      LCsv.Free;
    end;
  end;


var
  LCounter: Integer;

begin
  LSizeCSV := -1;
  LCounter := 5;
  while LCounter > 0 do
  begin
    Run();
    Dec(LCounter);
  end;

end;

procedure RunTests();
begin
  // ReadWriteAll;
//  ReadSize;
  ReadRandom;

  Readln;
end;

end.
