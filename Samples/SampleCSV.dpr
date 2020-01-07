program SampleCSV;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.Classes,
  System.SysUtils,
  System.CSV in '..\System.CSV.pas',
  Tests in 'Tests.pas',
  core.Field in '..\Src\core\core.Field.pas',
  core.Row in '..\Src\core\core.Row.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    RunTests;
  except
    on E: Exception do
      Writeln(E.Message);
  end;

end.
