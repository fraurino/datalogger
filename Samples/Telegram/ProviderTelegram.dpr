program ProviderTelegram;

uses
  Vcl.Forms,
  UProviderTelegram in 'UProviderTelegram.pas' {Form2},
  DataLogger.Provider.REST.HTTPClient in '..\..\src\Providers\DataLogger.Provider.REST.HTTPClient.pas',
  DataLogger.Provider.REST.Indy in '..\..\src\Providers\DataLogger.Provider.REST.Indy.pas',
  DataLogger.Provider.REST.NetHTTPClient in '..\..\src\Providers\DataLogger.Provider.REST.NetHTTPClient.pas',
  DataLogger.Provider.Telegram in '..\..\src\Providers\DataLogger.Provider.Telegram.pas',
  DataLogger in '..\..\src\Core\DataLogger.pas',
  DataLogger.Provider in '..\..\src\Core\DataLogger.Provider.pas',
  DataLogger.Simple in '..\..\src\Core\DataLogger.Simple.pas',
  DataLogger.Transaction in '..\..\src\Core\DataLogger.Transaction.pas',
  DataLogger.Types in '..\..\src\Core\DataLogger.Types.pas',
  DataLogger.Utils in '..\..\src\Core\DataLogger.Utils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
