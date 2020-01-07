unit core.Row;

interface

uses
  core.Field;

type
  IRow = interface
    ['{C61BB08F-C755-4D88-8369-69ADA7A8B39A}']
    procedure WriteField(AFieldName: string; AValue: string);
    function GetField(AFieldName: string): IField;
    property Field[AFieldName: string]: IField read GetField; default;
  end;

implementation

end.
