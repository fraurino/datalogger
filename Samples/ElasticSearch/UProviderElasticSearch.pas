unit UProviderElasticSearch;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Winapi.ShellAPI, System.JSON,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TForm2 = class(TForm)
    pnlInfo: TPanel;
    Panel1: TPanel;
    btnMakeLog: TButton;
    Memo1: TMemo;
    btnMakeLogCustom: TButton;
    procedure btnMakeLogClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure pnlInfoClick(Sender: TObject);
    procedure btnMakeLogCustomClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form2: TForm2;

implementation

{$R *.dfm}

uses
  DataLogger, DataLogger.Provider.ElasticSearch;

procedure TForm2.btnMakeLogClick(Sender: TObject);
begin
  Logger
    .Trace('My Trace')
    .Debug('My Debug')
    .Info('My Info')
    .Warn('My Warn')
    .Error('My Error')
    .Success('My Success')
    .Fatal('My Fatal')
    .Custom('Custom Level', 'My Custom')    
    ;
end;

procedure TForm2.btnMakeLogCustomClick(Sender: TObject);
var
  LJO: TJSONObject;
begin
  LJO := TJSONObject.Create;
  try
    LJO.AddPair('fields_custom1', 'my_value 1');
    LJO.AddPair('fields_custom2', 'my_value 2');
    LJO.AddPair('fields_custom3', 'my_value 3');
    LJO.AddPair('fields_custom4', 'my_value 4');
    LJO.AddPair('fields_custom5', 'my_value 5');

    Logger.Debug(LJO);
  finally
    LJO.Free;
  end;
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  ReportMemoryLeaksOnShutdown := True;

  Logger.AddProvider(
    TProviderElasticSearch.Create
    .URL('https://localhost:9200')
    .Index('logger')
    .BasicAuth('elastic', '{PASSWORD}')
    .SetLogException(
      procedure(const Sender: TObject; const LogItem: TLoggerItem; const E: Exception; var RetriesCount: Integer)
      begin
        if not Assigned(Memo1) then
          Exit;

        if (csDestroying in Memo1.ComponentState) then
          Exit;

        Memo1.Lines.Add(E.Message);
      end)
    );

  // Log Format
  Logger.SetLogFormat(TLoggerFormat.LOG_TIMESTAMP + ' - ' + TLoggerFormat.LOG_MESSAGE);
end;

procedure TForm2.pnlInfoClick(Sender: TObject);
var
  LURL: string;
begin
  LURL := pnlInfo.Caption;
  LURL := LURL.Replace('GITHUB: ', '').Replace(' ', '');

  ShellExecute(0, 'open', PChar(LURL), nil, nil, SW_SHOWNORMAL);
end;

end.
