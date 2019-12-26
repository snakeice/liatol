program SampleCSV;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.Classes,
  System.SysUtils,
  System.CSV in '..\System.CSV.pas',
  Testss in 'Testss.pas';


begin
  ReportMemoryLeaksOnShutdown := True;
  try
    RunTests;
  except
    on E: Exception do
      Writeln(E.Message);
  end;

end.
