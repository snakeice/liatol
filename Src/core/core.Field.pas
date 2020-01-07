unit core.Field;

interface

type

  IField = interface
    ['{C39F25EC-7FEB-4CD8-B44B-B741C49F9ADD}']
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

implementation

end.
