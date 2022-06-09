{
  *************************************
  Created by Danilo Lucas
  Github - https://github.com/dliocode
  *************************************
}

unit DataLogger;

interface

uses
  DataLogger.Provider, DataLogger.Types, DataLogger.Utils, System.Classes,
  System.SyncObjs, System.Generics.Collections, System.SysUtils, System.Threading, System.JSON;

type
  TLoggerItem = DataLogger.Types.TLoggerItem;
  TLoggerType = DataLogger.Types.TLoggerType;
  TLoggerTypes = DataLogger.Types.TLoggerTypes;
  TOnLogException = DataLogger.Types.TOnLogException;
  TDataLoggerProvider = DataLogger.Provider.TDataLoggerProvider;
  TLoggerFormat = DataLogger.Types.TLoggerFormat;

  TDataLogger = class sealed(TThread)
  strict private
    FCriticalSection: TCriticalSection;
    FEvent: TEvent;
    FListLoggerItem: TList<TLoggerItem>;
    FListProviders: TObjectList<TDataLoggerProvider>;
    FLogLevel: TLoggerType;
    FDisableLogType: TLoggerTypes;
    FOnlyLogType: TLoggerTypes;
    FSequence: UInt64;
    FName: string;

    constructor Create;
    procedure Start;

    function AddCache(const AType: TLoggerType; const AMessageString: string; const AMessageJSON: string; const ATag: string): TDataLogger; overload;
    function AddCache(const AType: TLoggerType; const AMessage: string; const ATag: string): TDataLogger; overload;
    function AddCache(const AType: TLoggerType; const AMessage: TJsonObject; const ATag: string): TDataLogger; overload;
    function ExtractCache: TArray<TLoggerItem>;
    procedure CloseProvider;
    function GetProviders: TArray<TDataLoggerProvider>;
    procedure Lock;
    procedure UnLock;
  protected
    procedure Execute; override;
  public
    function AddProvider(const AProvider: TDataLoggerProvider): TDataLogger;
    function RemoveProvider(const AProvider: TDataLoggerProvider): TDataLogger;
    function SetProvider(const AProviders: TArray<TDataLoggerProvider>): TDataLogger;

    function Trace(const AMessage: string; const ATag: string = ''): TDataLogger; overload;
    function Trace(const AMessage: string; const AArgs: array of const; const ATag: string = ''): TDataLogger; overload;
    function Trace(const AMessage: TJsonObject; const ATag: string = ''): TDataLogger; overload;
    function Debug(const AMessage: string; const ATag: string = ''): TDataLogger; overload;
    function Debug(const AMessage: string; const AArgs: array of const; const ATag: string = ''): TDataLogger; overload;
    function Debug(const AMessage: TJsonObject; const ATag: string = ''): TDataLogger; overload;
    function Info(const AMessage: string; const ATag: string = ''): TDataLogger; overload;
    function Info(const AMessage: string; const AArgs: array of const; const ATag: string = ''): TDataLogger; overload;
    function Info(const AMessage: TJsonObject; const ATag: string = ''): TDataLogger; overload;
    function Success(const AMessage: string; const ATag: string = ''): TDataLogger; overload;
    function Success(const AMessage: string; const AArgs: array of const; const ATag: string = ''): TDataLogger; overload;
    function Success(const AMessage: TJsonObject; const ATag: string = ''): TDataLogger; overload;
    function Warn(const AMessage: string; const ATag: string = ''): TDataLogger; overload;
    function Warn(const AMessage: string; const AArgs: array of const; const ATag: string = ''): TDataLogger; overload;
    function Warn(const AMessage: TJsonObject; const ATag: string = ''): TDataLogger; overload;
    function Error(const AMessage: string; const ATag: string = ''): TDataLogger; overload;
    function Error(const AMessage: string; const AArgs: array of const; const ATag: string = ''): TDataLogger; overload;
    function Error(const AMessage: TJsonObject; const ATag: string = ''): TDataLogger; overload;
    function Fatal(const AMessage: string; const ATag: string = ''): TDataLogger; overload;
    function Fatal(const AMessage: string; const AArgs: array of const; const ATag: string = ''): TDataLogger; overload;
    function Fatal(const AMessage: TJsonObject; const ATag: string = ''): TDataLogger; overload;
    function &Type(const AType: TLoggerType; const AMessage: string; const ATag: string = ''): TDataLogger; overload;
    function &Type(const AType: TLoggerType; const AMessage: TJsonObject; const ATag: string = ''): TDataLogger; overload;
    function SlineBreak: TDataLogger;

    function SetLogFormat(const ALogFormat: string): TDataLogger;
    function SetLogLevel(const ALogLevel: TLoggerType): TDataLogger;
    function SetOnlyLogType(const ALogType: TLoggerTypes): TDataLogger;
    function SetDisableLogType(const ALogType: TLoggerTypes): TDataLogger;
    function SetFormatTimestamp(const AFormatTimestamp: string): TDataLogger;
    function SetLogException(const AException: TOnLogException): TDataLogger;
    function SetMaxRetry(const AMaxRetry: Integer): TDataLogger;
    function SetName(const AName: string): TDataLogger;

    function StartTransaction: TDataLogger;
    function CommitTransaction: TDataLogger;
    function RollbackTransaction: TDataLogger;
    function InTransaction: Boolean;

    function Clear: TDataLogger;
    function CountLogInCache: Int64;

    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;

    class function Builder: TDataLogger;
  end;

function Logger: TDataLogger;

implementation

var
  FLoggerDefault: TDataLogger;

function Logger: TDataLogger;
begin
  if not Assigned(FLoggerDefault) then
    FLoggerDefault := TDataLogger.Builder;

  Result := FLoggerDefault;
end;

function TLogger: TDataLogger;
begin
  Result := Logger;
end;

{ TDataLogger }

class function TDataLogger.Builder: TDataLogger;
begin
  Result := TDataLogger.Create;
end;

constructor TDataLogger.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
end;

procedure TDataLogger.AfterConstruction;
begin
  inherited;

  FCriticalSection := TCriticalSection.Create;
  FEvent := TEvent.Create;
  FListLoggerItem := TList<TLoggerItem>.Create;
  FListProviders := TObjectList<TDataLoggerProvider>.Create(True);

  SetLogLevel(TLoggerType.All);
  SetDisableLogType([]);
  SetOnlyLogType([TLoggerType.All]);
  SetName('');

  FSequence := 0;

  Start;
end;

procedure TDataLogger.BeforeDestruction;
begin
  SetDisableLogType([TLoggerType.All]);

  Terminate;
  FEvent.SetEvent;
  WaitFor;

  CloseProvider;

  Lock;
  try
    FListProviders.Free;
    FListLoggerItem.Free;
    FEvent.Free;
  finally
    UnLock;
  end;

  FCriticalSection.Free;

  inherited;
end;

procedure TDataLogger.Start;
begin
  inherited Start;
end;

procedure TDataLogger.Execute;
var
  LCache: TArray<TLoggerItem>;
  LProviders: TArray<TDataLoggerProvider>;
begin
  while not Terminated do
  begin
    FEvent.WaitFor(INFINITE);
    FEvent.ResetEvent;

    LProviders := GetProviders;

    if Length(LProviders) = 0 then
      Continue;

    LCache := ExtractCache;
    if Length(LCache) = 0 then
      Continue;

    TParallel.For(Low(LProviders), High(LProviders),
      procedure(Index: Integer)
      begin
        LProviders[Index].AddCache(LCache);
      end);
  end;
end;

function TDataLogger.AddProvider(const AProvider: TDataLoggerProvider): TDataLogger;
begin
  Result := Self;

  Lock;
  try
    FListProviders.Add(AProvider);
  finally
    UnLock;
  end;
end;

function TDataLogger.RemoveProvider(const AProvider: TDataLoggerProvider): TDataLogger;
begin
  Result := Self;

  Lock;
  try
    FListProviders.Remove(AProvider);
  finally
    UnLock;
  end;
end;

function TDataLogger.SetProvider(const AProviders: TArray<TDataLoggerProvider>): TDataLogger;
var
  LItem: TDataLoggerProvider;
begin
  Result := Self;

  Lock;
  try
    FListProviders.Clear;
    FListProviders.TrimExcess;
  finally
    UnLock;
  end;

  for LItem in AProviders do
    AddProvider(LItem);
end;

function TDataLogger.Trace(const AMessage: string; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(TLoggerType.Trace, AMessage, ATag);
end;

function TDataLogger.Trace(const AMessage: string; const AArgs: array of const; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Trace, Format(AMessage, AArgs), ATag);
end;

function TDataLogger.Trace(const AMessage: TJsonObject; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Trace, AMessage, ATag);
end;

function TDataLogger.Debug(const AMessage: string; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(TLoggerType.Debug, AMessage, ATag);
end;

function TDataLogger.Debug(const AMessage: string; const AArgs: array of const; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Debug, Format(AMessage, AArgs), ATag);
end;

function TDataLogger.Debug(const AMessage: TJsonObject; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Debug, AMessage, ATag);
end;

function TDataLogger.Info(const AMessage: string; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(TLoggerType.Info, AMessage, ATag);
end;

function TDataLogger.Info(const AMessage: string; const AArgs: array of const; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Info, Format(AMessage, AArgs), ATag);
end;

function TDataLogger.Info(const AMessage: TJsonObject; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Info, AMessage, ATag);
end;

function TDataLogger.Success(const AMessage: string; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(TLoggerType.Success, AMessage, ATag);
end;

function TDataLogger.Success(const AMessage: string; const AArgs: array of const; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Success, Format(AMessage, AArgs), ATag);
end;

function TDataLogger.Success(const AMessage: TJsonObject; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Success, AMessage, ATag);
end;

function TDataLogger.Warn(const AMessage: string; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(TLoggerType.Warn, AMessage, ATag);
end;

function TDataLogger.Warn(const AMessage: string; const AArgs: array of const; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Warn, Format(AMessage, AArgs), ATag);
end;

function TDataLogger.Warn(const AMessage: TJsonObject; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Warn, AMessage, ATag);
end;

function TDataLogger.Error(const AMessage: string; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(TLoggerType.Error, AMessage, ATag);
end;

function TDataLogger.Error(const AMessage: string; const AArgs: array of const; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Error, Format(AMessage, AArgs), ATag);
end;

function TDataLogger.Error(const AMessage: TJsonObject; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Error, AMessage, ATag);
end;

function TDataLogger.Fatal(const AMessage: string; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(TLoggerType.Fatal, AMessage, ATag);
end;

function TDataLogger.Fatal(const AMessage: string; const AArgs: array of const; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Fatal, Format(AMessage, AArgs), ATag);
end;

function TDataLogger.Fatal(const AMessage: TJsonObject; const ATag: string): TDataLogger;
begin
  Result := AddCache(TLoggerType.Fatal, AMessage, ATag);
end;

function TDataLogger.&Type(const AType: TLoggerType; const AMessage: string; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(AType, AMessage, ATag);
end;

function TDataLogger.&Type(const AType: TLoggerType; const AMessage: TJsonObject; const ATag: string = ''): TDataLogger;
begin
  Result := AddCache(AType, AMessage, ATag);
end;

function TDataLogger.SlineBreak: TDataLogger;
begin
  Result := AddCache(TLoggerType.All, '', '');
end;

function TDataLogger.SetLogFormat(const ALogFormat: string): TDataLogger;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := Self;

  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].SetLogFormat(ALogFormat);
    end);
end;

function TDataLogger.SetFormatTimestamp(const AFormatTimestamp: string): TDataLogger;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := Self;

  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].SetFormatTimestamp(AFormatTimestamp);
    end);
end;

function TDataLogger.SetLogLevel(const ALogLevel: TLoggerType): TDataLogger;
begin
  Result := Self;

  Lock;
  try
    FLogLevel := ALogLevel;
  finally
    UnLock;
  end;
end;

function TDataLogger.SetDisableLogType(const ALogType: TLoggerTypes): TDataLogger;
begin
  Result := Self;

  Lock;
  try
    FDisableLogType := ALogType;
  finally
    UnLock;
  end;
end;

function TDataLogger.SetOnlyLogType(const ALogType: TLoggerTypes): TDataLogger;
begin
  Result := Self;

  Lock;
  try
    FOnlyLogType := ALogType;
  finally
    UnLock;
  end;
end;

function TDataLogger.SetLogException(const AException: TOnLogException): TDataLogger;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := Self;

  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].SetLogException(AException);
    end);
end;

function TDataLogger.SetMaxRetry(const AMaxRetry: Integer): TDataLogger;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := Self;

  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].SetMaxRetry(AMaxRetry);
    end);
end;

function TDataLogger.SetName(const AName: string): TDataLogger;
begin
  Result := Self;

  Lock;
  try
    FName := AName;
  finally
    UnLock;
  end;
end;

function TDataLogger.StartTransaction: TDataLogger;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := Self;

  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].StartTransaction;
    end);
end;

function TDataLogger.CommitTransaction: TDataLogger;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := Self;

  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].CommitTransaction;
    end);
end;

function TDataLogger.RollbackTransaction: TDataLogger;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := Self;

  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].RollbackTransaction;
    end);
end;

function TDataLogger.InTransaction: Boolean;
var
  LProviders: TArray<TDataLoggerProvider>;
  LProvider: TDataLoggerProvider;
begin
  Result := False;

  LProviders := GetProviders;

  for LProvider in LProviders do
  begin
    Result := LProvider.InTransaction;

    if Result then
      Break;
  end;
end;

function TDataLogger.Clear: TDataLogger;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := Self;

  Lock;
  try
    FListLoggerItem.Clear;
    FListLoggerItem.TrimExcess;
  finally
    UnLock;
  end;

  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].Clear;
    end);
end;

function TDataLogger.CountLogInCache: Int64;
begin
  Lock;
  try
    Result := FListLoggerItem.Count;
  finally
    UnLock;
  end;
end;

function TDataLogger.AddCache(const AType: TLoggerType; const AMessageString: string; const AMessageJSON: string; const ATag: string): TDataLogger;
var
  LLogItem: TLoggerItem;
begin
  Result := Self;

  Lock;
  try
    if (TLoggerType.All in FDisableLogType) or (AType in FDisableLogType) then
      Exit;

    if not(TLoggerType.All in FOnlyLogType) and not(AType in FOnlyLogType) then
      Exit;

    if not(AType in FOnlyLogType) then
      if Ord(FLogLevel) > Ord(AType) then
        Exit;

    if not(AType = TLoggerType.All) then
    begin
      if FSequence = 18446744073709551615 then
        FSequence := 0;
      Inc(FSequence);
    end;

    LLogItem := default (TLoggerItem);
    LLogItem.Name := FName;
    LLogItem.Sequence := FSequence;
    LLogItem.TimeStamp := Now;
    LLogItem.ThreadID := TThread.Current.ThreadID;
    LLogItem.&Type := AType;
    LLogItem.Tag := ATag;
    LLogItem.Message := AMessageString;
    LLogItem.MessageJSON := AMessageJSON;

    LLogItem.AppName := TLoggerUtils.AppName;
    LLogItem.AppPath := TLoggerUtils.AppPath;
    LLogItem.AppVersion := TLoggerUtils.AppVersion;
    LLogItem.AppSize := TLoggerUtils.AppSize;

    LLogItem.ComputerName := TLoggerUtils.ComputerName;
    LLogItem.Username := TLoggerUtils.Username;
    LLogItem.OSVersion := TLoggerUtils.OS;
    LLogItem.ProcessID := TLoggerUtils.ProcessID.ToString;
    LLogItem.IPLocal := TLoggerUtils.IPLocal;

    FListLoggerItem.Add(LLogItem);
  finally
    FEvent.SetEvent;
    UnLock;
  end;
end;

function TDataLogger.AddCache(const AType: TLoggerType; const AMessage: string; const ATag: string): TDataLogger;
begin
  Result := AddCache(AType, AMessage, '', ATag);
end;

function TDataLogger.AddCache(const AType: TLoggerType; const AMessage: TJsonObject; const ATag: string): TDataLogger;
begin
  Result := AddCache(AType, '', AMessage.ToString, ATag);
end;

function TDataLogger.ExtractCache: TArray<TLoggerItem>;
var
  LCache: TArray<TLoggerItem>;
begin
  Lock;
  try
    LCache := FListLoggerItem.ToArray;

    FListLoggerItem.Clear;
    FListLoggerItem.TrimExcess;
  finally
    UnLock;
  end;

  Result := LCache;
end;

procedure TDataLogger.CloseProvider;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  LProviders := GetProviders;

  TParallel.For(Low(LProviders), High(LProviders),
    procedure(Index: Integer)
    begin
      LProviders[Index].NotifyEvent;
    end);
end;

function TDataLogger.GetProviders: TArray<TDataLoggerProvider>;
var
  LProviders: TArray<TDataLoggerProvider>;
begin
  Result := [];

  Lock;
  try
    LProviders := FListProviders.ToArray;
  finally
    UnLock;
  end;

  Result := LProviders;
end;

procedure TDataLogger.Lock;
begin
  FCriticalSection.Acquire;
end;

procedure TDataLogger.UnLock;
begin
  FCriticalSection.Release;
end;

initialization

finalization

if Assigned(FLoggerDefault) then
begin
  FLoggerDefault.Free;
  FLoggerDefault := nil;
end;

end.