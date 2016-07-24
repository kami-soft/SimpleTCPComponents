unit ufmMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, System.Win.ScktComp, uDataTransfer;

type
  TForm11 = class(TForm)
    grpServer: TGroupBox;
    grpClient: TGroupBox;
    edtSendFromServer: TEdit;
    btnSendFromServer: TButton;
    spl1: TSplitter;
    mmoReceivedOnServer: TMemo;
    edtSendFromClient: TEdit;
    btnSendFromClient: TButton;
    mmoReceivedOnClient: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnSendFromServerClick(Sender: TObject);
    procedure btnSendFromClientClick(Sender: TObject);
  private
    { Private declarations }
    FDataTransferServer: TDataTransferServer;
    FDataTransferClient: TDataTransferClient;

    procedure OnServerReceiveData(Sender: TObject; Socket: TCustomWinSocket; Data: TStream);
    procedure OnClientReceiveData(Sender: TObject; Socket: TCustomWinSocket; Data: TStream);
  public
    { Public declarations }
  end;

var
  Form11: TForm11;

implementation

{$R *.dfm}

procedure TForm11.btnSendFromClientClick(Sender: TObject);
begin
  // we have several variants of SendData method.
  // see uDataTransfer.pas
  FDataTransferClient.SendData(edtSendFromClient.Text);
end;

procedure TForm11.btnSendFromServerClick(Sender: TObject);
begin
  // we have several variants of SendToAll.
  // and SendToSingleConnection methods
  // see uDataTransfer.pas
  FDataTransferServer.SendToAll(edtSendFromServer.Text);
end;

procedure TForm11.FormCreate(Sender: TObject);
begin
  FDataTransferServer := TDataTransferServer.Create(Self);
  FDataTransferServer.TCPPort := 5005; // dont forget about firewall !!!
  FDataTransferServer.OnReceiveData := OnServerReceiveData;
  FDataTransferServer.Active := True;

  FDataTransferClient := TDataTransferClient.Create(Self);
  FDataTransferClient.CanAutoRecreateSocket := True; // allow to reconnect and
  // automatically resend data if connection break
  FDataTransferClient.IP := '127.0.0.1'; // server address.
  FDataTransferClient.TCPPort := 5005; // same port as on DataTransferServer
  FDataTransferClient.OnReceiveData := OnClientReceiveData;
  FDataTransferClient.Active:=True;
end;

procedure TForm11.OnClientReceiveData(Sender: TObject; Socket: TCustomWinSocket; Data: TStream);
begin
  //we are sure that the correspondent sends us only the strings
  mmoReceivedOnClient.Lines.Add(ReadStringFromStream(Data));

  // after processed we should free data
  Data.Free;
end;

procedure TForm11.OnServerReceiveData(Sender: TObject; Socket: TCustomWinSocket; Data: TStream);
begin
  //we are sure that the correspondent sends us only the strings
  mmoReceivedOnServer.Lines.Add(ReadStringFromStream(Data));

  // after processed we should free data
  Data.Free;
end;

end.
