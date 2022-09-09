{
  *************************************
  Created by Danilo Lucas
  Github - https://github.com/dliocode
  *************************************
}

// https://firebase.google.com/

unit DataLogger.Provider.Firebase.RealtimeDatabase;

interface

uses
  DataLogger.Provider, DataLogger.Types,
{$IF DEFINED(DATALOGGER_FIREBASE_REALTIMEDATABASE_USE_INDY)}
  DataLogger.Provider.REST.Indy,
{$ELSEIF DEFINED(DATALOGGER_FIREBASE_REALTIMEDATABASE_USE_NETHTTPCLIENT)}
  DataLogger.Provider.REST.NetHTTPClient,
{$ELSE}
  DataLogger.Provider.REST.HTTPClient,
{$ENDIF}
  System.SysUtils, System.Classes, System.JSON;

type
  TProviderRealtimeDatabase = class(TDataLoggerProvider<TProviderRealtimeDatabase>)
  private
    type
    TProviderHTTP = class(
{$IF DEFINED(DATALOGGER_FIREBASE_REALTIMEDATABASE_USE_INDY)}
      TProviderRESTIndy
{$ELSEIF DEFINED(DATALOGGER_FIREBASE_REALTIMEDATABASE_USE_NETHTTPCLIENT)}
      TProviderRESTNetHTTPClient
{$ELSE}
      TProviderRESTHTTPClient
{$ENDIF});

  private
    FHTTP: TProviderHTTP;
    FDataBase: string;
  protected
    procedure Save(const ACache: TArray<TLoggerItem>); override;
  public
    function URL(const AValue: string): TProviderRealtimeDatabase;
    function DataBase(const AValue: string): TProviderRealtimeDatabase;

    procedure LoadFromJSON(const AJSON: string); override;
    function ToJSON(const AFormat: Boolean = False): string; override;

    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TProviderRealtimeDatabase }

constructor TProviderRealtimeDatabase.Create;
begin
  inherited Create;

  FHTTP := TProviderHTTP.Create;
  FHTTP.ContentType('application/json');

  DataBase('datalogger');
end;

destructor TProviderRealtimeDatabase.Destroy;
begin
  FHTTP.Free;
  inherited;
end;

function TProviderRealtimeDatabase.URL(const AValue: string): TProviderRealtimeDatabase;
begin
  Result := Self;
  FHTTP.URL(AValue);
end;

function TProviderRealtimeDatabase.DataBase(const AValue: string): TProviderRealtimeDatabase;
begin
  Result := Self;
  FDataBase := AValue;
end;

procedure TProviderRealtimeDatabase.LoadFromJSON(const AJSON: string);
var
  LJO: TJSONObject;
begin
  if AJSON.Trim.IsEmpty then
    Exit;

  try
    LJO := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  except
    on E: Exception do
      Exit;
  end;

  if not Assigned(LJO) then
    Exit;

  try
    URL(LJO.GetValue<string>('url', FHTTP.URL));
    DataBase(LJO.GetValue<string>('database', FDataBase));

    SetJSONInternal(LJO);
  finally
    LJO.Free;
  end;
end;

function TProviderRealtimeDatabase.ToJSON(const AFormat: Boolean): string;
var
  LJO: TJSONObject;
begin
  LJO := TJSONObject.Create;
  try
    LJO.AddPair('url', FHTTP.URL);
    LJO.AddPair('database', FDataBase);

    ToJSONInternal(LJO);

    Result := TLoggerJSON.Format(LJO, AFormat);
  finally
    LJO.Free;
  end;
end;

procedure TProviderRealtimeDatabase.Save(const ACache: TArray<TLoggerItem>);
var
  LItemREST: TArray<TLogItemREST>;
  LItem: TLoggerItem;
  LLog: string;
  LLogItemREST: TLogItemREST;
begin
  LItemREST := [];

  if Length(ACache) = 0 then
    Exit;

  for LItem in ACache do
  begin
    if LItem.InternalItem.TypeSlineBreak then
      Continue;

    LLog := TLoggerLogFormat.AsJsonObjectToString(FLogFormat, LItem, True);

    LLogItemREST.Stream := TStringStream.Create(LLog, TEncoding.UTF8);
    LLogItemREST.LogItem := LItem;
    LLogItemREST.URL := Format('%s/%s.json', [FHTTP.URL.Trim(['/']), FDataBase]);

    LItemREST := Concat(LItemREST, [LLogItemREST]);
  end;

  FHTTP.InternalSave(TRESTMethod.tlmPost, LItemREST);
end;

procedure ForceReferenceToClass(C: TClass);
begin
end;

initialization

ForceReferenceToClass(TProviderRealtimeDatabase);

end.
