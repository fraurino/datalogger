{
  *************************************
  Created by Danilo Lucas
  Github - https://github.com/dliocode
  *************************************
}

unit DataLogger.Provider.REST.HTTPClient;

interface

uses
  DataLogger.Provider, DataLogger.Types,
  System.SysUtils, System.Classes, System.Threading, System.Net.HTTPClient, System.Net.URLClient, System.NetConsts;

type
  THTTPClient = System.Net.HTTPClient.THTTPClient;

  TLogItemREST = record
    Stream: TStream;
    LogItem: TLoggerItem;
    URL: string;
  end;

  TLogItemResponse = record
    LogItem: TLoggerItem;
    Content: string;
  end;

  TExecuteFinally = reference to procedure(const ALogItem: TLoggerItem; const AContent: string);
  TLoggerMethod = (tlmGet, tlmPost);

  TProviderRESTHTTPClient = class(TDataLoggerProvider)
  private
    FURL: string;
    FContentType: string;
    FToken: string;
    FMethod: TLoggerMethod;
    FExecuteFinally: TExecuteFinally;
    procedure HTTP(const AMethod: TLoggerMethod; const AItemREST: TLogItemREST);
  protected
    procedure InternalSave(const AMethod: TLoggerMethod; const ALogItemREST: TArray<TLogItemREST>);
    procedure InternalSaveAsync(const AMethod: TLoggerMethod; const ALogItemREST: TArray<TLogItemREST>);

    procedure Save(const ACache: TArray<TLoggerItem>); override;
  public
    function URL(const AValue: string): TProviderRESTHTTPClient; overload;
    function URL: string; overload;
    function ContentType(const AValue: string): TProviderRESTHTTPClient;
    function BearerToken(const AValue: string): TProviderRESTHTTPClient;
    function Token(const AValue: string): TProviderRESTHTTPClient;
    function Method(const AValue: TLoggerMethod): TProviderRESTHTTPClient;
    function ExecuteFinally(const AExecuteFinally: TExecuteFinally): TProviderRESTHTTPClient;

    constructor Create; overload;
    constructor Create(const AURL: string; const AContentType: string = 'text/plain'; const AToken: string = ''); overload; deprecated 'Use TProviderRESTHTTPClient.Create.URL('').ContentType(''application/json'').BearerToken(''aaaa'') - This function will be removed in future versions';
  end;

implementation

{ TProviderRESTHTTPClient }

constructor TProviderRESTHTTPClient.Create;
begin
  inherited Create;

  URL('');
  ContentType('text/plain');
  Token('');
  Method(tlmPost);
end;

constructor TProviderRESTHTTPClient.Create(const AURL: string; const AContentType: string = 'text/plain'; const AToken: string = '');
var
  LProtocol: string;
  LHost: string;
begin
  Create;

  LProtocol := 'http://';
  LHost := AURL;

  if not LHost.ToLower.StartsWith('http://') and not LHost.ToLower.StartsWith('https://') then
    LHost := LProtocol + AURL;

  URL(LHost);
  Token(AToken);
  ContentType(AContentType);

  if FContentType.Trim.IsEmpty then
    ContentType('text/plain');

  ExecuteFinally(nil);
end;

function TProviderRESTHTTPClient.URL(const AValue: string): TProviderRESTHTTPClient;
var
  LProtocol: string;
begin
  Result := Self;

  LProtocol := 'http://';

  FURL := AValue;
  if not AValue.ToLower.StartsWith('http://') and not AValue.ToLower.StartsWith('https://') then
    FURL := LProtocol + AValue;
end;

function TProviderRESTHTTPClient.URL: string;
begin
  Result := FURL;
end;

function TProviderRESTHTTPClient.ContentType(const AValue: string): TProviderRESTHTTPClient;
begin
  Result := Self;
  FContentType := AValue;
end;

function TProviderRESTHTTPClient.BearerToken(const AValue: string): TProviderRESTHTTPClient;
begin
  Result := Self;
  FToken := 'Bearer ' + AValue;
end;

function TProviderRESTHTTPClient.Token(const AValue: string): TProviderRESTHTTPClient;
begin
  Result := Self;
  FToken := AValue;
end;

function TProviderRESTHTTPClient.Method(const AValue: TLoggerMethod): TProviderRESTHTTPClient;
begin
  Result := Self;
  FMethod := AValue;
end;

function TProviderRESTHTTPClient.ExecuteFinally(const AExecuteFinally: TExecuteFinally): TProviderRESTHTTPClient;
begin
  Result := Self;
  FExecuteFinally := AExecuteFinally;
end;

procedure TProviderRESTHTTPClient.Save(const ACache: TArray<TLoggerItem>);
var
  LItemREST: TArray<TLogItemREST>;
  LItem: TLoggerItem;
  LLogItemREST: TLogItemREST;
begin
  LItemREST := [];

  if Length(ACache) = 0 then
    Exit;

  for LItem in ACache do
  begin
    if LItem.&Type = TLoggerType.All then
      Continue;

    if Trim(LowerCase(FContentType)) = 'application/json' then
      LLogItemREST.Stream := TLoggerLogFormat.AsStreamJsonObject(FLogFormat, LItem)
    else
      LLogItemREST.Stream := TLoggerLogFormat.AsStream(FLogFormat, LItem, FFormatTimestamp);

    LLogItemREST.LogItem := LItem;

    LItemREST := Concat(LItemREST, [LLogItemREST]);
  end;

  InternalSaveAsync(FMethod, LItemREST);
end;

procedure TProviderRESTHTTPClient.InternalSave(const AMethod: TLoggerMethod; const ALogItemREST: TArray<TLogItemREST>);
var
  I: Integer;
begin
  if Length(ALogItemREST) = 0 then
    Exit;

  for I := Low(ALogItemREST) to High(ALogItemREST) do
    HTTP(AMethod, ALogItemREST[I]);
end;

procedure TProviderRESTHTTPClient.InternalSaveAsync(const AMethod: TLoggerMethod; const ALogItemREST: TArray<TLogItemREST>);
begin
  if Length(ALogItemREST) = 0 then
    Exit;

  TParallel.For(Low(ALogItemREST), High(ALogItemREST),
    procedure(Index: Integer)
    begin
      HTTP(AMethod, ALogItemREST[Index]);
    end);
end;

procedure TProviderRESTHTTPClient.HTTP(const AMethod: TLoggerMethod; const AItemREST: TLogItemREST);
var
  LRetryCount: Integer;
  LURL: string;
  LHTTP: THTTPClient;
  LResponse: IHTTPResponse;
  LResponseContent: string;
begin
  if Self.Terminated then
  begin
    if Assigned(AItemREST.Stream) then
      AItemREST.Stream.Free;

    Exit;
  end;

  LURL := AItemREST.URL;
  if LURL.Trim.IsEmpty then
    LURL := FURL;

  if LURL.Trim.IsEmpty then
    raise EDataLoggerException.Create('URL is empty');

  try
    LHTTP := THTTPClient.Create;
  except
    if Assigned(AItemREST.Stream) then
      AItemREST.Stream.Free;

    Exit
  end;

  try
{$IF RTLVersion > 32} // 32 = Delphi Tokyo (10.2)
    LHTTP.ConnectionTimeout := 60000;
    LHTTP.ResponseTimeout := 60000;
    LHTTP.SendTimeout := 60000;
{$ENDIF}
    LHTTP.HandleRedirects := True;
    LHTTP.UserAgent := 'DataLogger.Provider.REST.HTTPClient';
    LHTTP.ContentType := FContentType;

    LHTTP.AcceptCharSet := 'utf-8';
    LHTTP.AcceptEncoding := 'utf-8';
    LHTTP.Accept := FContentType;

    if not FToken.Trim.IsEmpty then
      LHTTP.CustomHeaders['Authorization'] := FToken;

    LRetryCount := 0;

    while True do
      try
        if Self.Terminated then
          Exit;

        case AMethod of
          tlmGet:
            LResponse := LHTTP.Get(LURL);
          tlmPost:
            LResponse := LHTTP.Post(LURL, AItemREST.Stream);
        end;

        LResponseContent := LResponse.ContentAsString(TEncoding.UTF8);

        if not(LResponse.StatusCode in [200, 201]) then
          raise EDataLoggerException.Create(LResponseContent);

        Break;
      except
        on E: Exception do
        begin
          Inc(LRetryCount);

          Sleep(50);

          if Assigned(FLogException) then
            FLogException(Self, AItemREST.LogItem, E, LRetryCount);

          if Self.Terminated then
            Exit;

          if LRetryCount >= FMaxRetry then
            Break;
        end;
      end;
  finally
    LHTTP.Free;

    if Assigned(FExecuteFinally) then
      FExecuteFinally(AItemREST.LogItem, LResponseContent);

    if Assigned(AItemREST.Stream) then
      AItemREST.Stream.Free;
  end;
end;

end.
