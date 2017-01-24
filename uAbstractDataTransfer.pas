unit uAbstractDataTransfer;
{$I SimpleTCPComponents.inc}
interface

uses
  Messages,
  Classes,
  Contnrs,
  ScktComp,
  uPacketStream;

const
  SocketBuffSize = 8192;

type
  TReceiveEvent = procedure(Sender: TObject; Socket: TCustomWinSocket; Data: TStream) of object;

  TDeferredReceiveItem = record
    Socket: TCustomWinSocket;
    Data: TStream;
  end;

  PDeferredReceiveItem = ^TDeferredReceiveItem;

  TDeferredReceiveContainer = class(TList)
  private
    function ExtractByIndex(Index: Integer; out Socket: TCustomWinSocket; out Data: TStream): Boolean;

    function GetItem(Index: Integer): PDeferredReceiveItem;
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  public
    procedure AddNew(Socket: TCustomWinSocket; Data: TStream);
    function ExtractFirst(out Socket: TCustomWinSocket; out Data: TStream): Boolean;

    function ExtractBySocket(Socket: TCustomWinSocket; out Data: TStream): Boolean;
  end;

  TAbstractDataTransfer = class(TComponent)
  private
    FInPacketClass: TInPacketStreamClass;
    FOutPacketClass: TOutPacketStreamClass;

    FOnConnected: TSocketNotifyEvent;
    FOnDisconnected: TSocketNotifyEvent;
    FOnReceiveData: TReceiveEvent;

    FActive: Boolean;

    FMaxQueueCount: Integer;
    FTCPPort: Integer;
{$IFDEF ExtScktComp}
    FBindIP: string;
{$ENDIF}
    FDeferredReceiveItems: TDeferredReceiveContainer;
  protected
    FWndHandle: THandle;

    FReadBufferSize: Integer;
    FReadBuffer: PAnsiChar;
    FOutBuffer: packed array [0 .. SocketBuffSize] of byte;

    FInReceive: Boolean;
    procedure WndProc(var message: TMessage); virtual;

    function CreateInStream: TAbstractInPacketStream;
    function CreateOutStream: TAbstractOutPacketStream;

{$IFDEF ExtScktComp}
    procedure SetBindIP(const Value: string); virtual;
{$ENDIF}
    procedure OnConnect(Sender: TObject; Socket: TCustomWinSocket); virtual;
    procedure OnDisconnect(Sender: TObject; Socket: TCustomWinSocket); virtual;
    procedure OnRead(Sender: TObject; Socket: TCustomWinSocket); virtual;
    procedure OnWrite(Sender: TObject; Socket: TCustomWinSocket); virtual;
    procedure OnError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer); virtual;

    procedure DoConnected(Socket: TCustomWinSocket);
    procedure DoDisconnected(Socket: TCustomWinSocket);
    procedure DoReceiveData(Socket: TCustomWinSocket; Data: TStream);

    procedure SetActive(const Value: Boolean); virtual;
    procedure SetTCPPort(const Value: Integer); virtual;

    function GetOutDataList(Socket: TCustomWinSocket): TObjectList; virtual; abstract;

    procedure SetCurrentInStream(Socket: TCustomWinSocket; Stream: TAbstractInPacketStream); virtual; abstract;
    function GetCurrentInStream(Socket: TCustomWinSocket): TAbstractInPacketStream; virtual; abstract;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property Active: Boolean read FActive write SetActive;

    property InPacketClass: TInPacketStreamClass read FInPacketClass write FInPacketClass;
    property OutPacketClass: TOutPacketStreamClass read FOutPacketClass write FOutPacketClass;

  published
    property MaxQueueCount: Integer read FMaxQueueCount write FMaxQueueCount default 10000;

{$IFDEF ExtScktComp}
    property BindIP: string read FBindIP write SetBindIP;
{$ENDIF}
    property TCPPort: Integer read FTCPPort write SetTCPPort;
    property OnReceiveData: TReceiveEvent read FOnReceiveData write FOnReceiveData;
    property OnConnected: TSocketNotifyEvent read FOnConnected write FOnConnected;
    property OnDisconnected: TSocketNotifyEvent read FOnDisconnected write FOnDisconnected;
  end;

implementation
uses
  Windows, SysUtils, WinSock;

const
  WM_DEFERRED_RECEIVE = WM_USER;

  { TDeferredReceiveContainer }

procedure TDeferredReceiveContainer.AddNew(Socket: TCustomWinSocket; Data: TStream);
var
  Item: PDeferredReceiveItem;
begin
  New(Item);
  Add(Item);
  Item.Socket := Socket;
  Item.Data := Data;
end;

function TDeferredReceiveContainer.ExtractByIndex(Index: Integer; out Socket: TCustomWinSocket; out Data: TStream): Boolean;
var
  Item: PDeferredReceiveItem;
begin
  Item := GetItem(Index);
  if Assigned(Item) then
    begin
      Socket := Item.Socket;
      Data := Item.Data;

      Delete(Index);
      Result := true;
    end
  else
    Result := False;
end;

function TDeferredReceiveContainer.ExtractBySocket(Socket: TCustomWinSocket; out Data: TStream): Boolean;
var
  i: Integer;
  Item: PDeferredReceiveItem;
begin
  Result := False;
  Data := nil;
  for i := 0 to Count - 1 do
    begin
      Item := GetItem(i);
      if Assigned(Item) then
        if Item.Socket = Socket then
          begin
            Result := ExtractByIndex(i, Socket, Data);
            break;
          end;
    end;
end;

function TDeferredReceiveContainer.ExtractFirst(out Socket: TCustomWinSocket; out Data: TStream): Boolean;
begin
  Result := False;
  if Count <> 0 then
    Result := ExtractByIndex(0, Socket, Data);
end;

function TDeferredReceiveContainer.GetItem(Index: Integer): PDeferredReceiveItem;
begin
  if (Index < 0) or (Index >= Count) then
    Result := nil
  else
    Result := PDeferredReceiveItem(Items[Index]);
end;

procedure TDeferredReceiveContainer.Notify(Ptr: Pointer; Action: TListNotification);
begin
  if Action in [lnExtracted, lnDeleted] then
    Dispose(PDeferredReceiveItem(Ptr));
  inherited;
end;

{ TAbstractDataTransfer }

constructor TAbstractDataTransfer.Create(AOwner: TComponent);
begin
  inherited;
  FDeferredReceiveItems := TDeferredReceiveContainer.Create;
  FWndHandle := AllocateHWnd(WndProc);

  FReadBufferSize := SocketBuffSize;
  FReadBuffer := AllocMem(SocketBuffSize);

  FMaxQueueCount := 10000;
  FInPacketClass := TInPacketStream;
  FOutPacketClass := TOutPacketStream;
end;

function TAbstractDataTransfer.CreateInStream: TAbstractInPacketStream;
begin
  Result := FInPacketClass.Create;
end;

function TAbstractDataTransfer.CreateOutStream: TAbstractOutPacketStream;
begin
  Result := FOutPacketClass.Create;
end;

destructor TAbstractDataTransfer.Destroy;
begin
  FreeMem(FReadBuffer);
  DeallocateHWnd(FWndHandle);
  FreeAndNil(FDeferredReceiveItems);
  inherited;
end;

procedure TAbstractDataTransfer.DoConnected(Socket: TCustomWinSocket);
begin
  if Assigned(FOnConnected) then
    FOnConnected(Self, Socket);
end;

procedure TAbstractDataTransfer.DoDisconnected(Socket: TCustomWinSocket);
begin
  if Assigned(FOnDisconnected) then
    FOnDisconnected(Self, Socket);
end;

procedure TAbstractDataTransfer.DoReceiveData(Socket: TCustomWinSocket; Data: TStream);
begin
  if Assigned(FOnReceiveData) then
    FOnReceiveData(Self, Socket, Data)
  else
    Data.Free;
end;

procedure TAbstractDataTransfer.OnConnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  DoConnected(Socket);
end;

procedure TAbstractDataTransfer.OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
var
  tmpStream: TStream;
  tmpSocket: TCustomWinSocket;
begin
  while FDeferredReceiveItems.ExtractFirst(tmpSocket, tmpStream) do
    DoReceiveData(tmpSocket, tmpStream);

  DoDisconnected(Socket);
end;

procedure TAbstractDataTransfer.OnError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
  { Здесь реализован минимальный обработчик события ошибки.
    Чтобы не возбуждалось исключение, код ошибки обнуляем
    и закрываем соединение, бо оно все равно уже неработоспособно.
    Еще раз обращаю внимание - для компонентов TClient|TServerSocket
    эти две строчки - МИНИМАЛЬНЫЙ код, который ОБЯЗАН быть в этом событии,
    если иное не предусмотрено логикой программы. }
  ErrorCode := 0;
  Socket.Close;
end;

procedure TAbstractDataTransfer.OnRead(Sender: TObject; Socket: TCustomWinSocket);
var
  Readed, ReceiveCount: Integer;
  ReadPos: Integer;
  InStream: TAbstractInPacketStream;
  tmpStream: TStream;
begin
  ReceiveCount := Socket.ReceiveLength;
  ReadPos := 0;

  if ReceiveCount = 0 then
    exit
  else
    if ReceiveCount > FReadBufferSize then
      begin
        FReadBufferSize := (ReceiveCount + 1024) and $FFFFFC00;
        ReallocMem(FReadBuffer, FReadBufferSize);
      end;

  Readed := Socket.ReceiveBuf(FReadBuffer[0], ReceiveCount);

  while ReadPos < Readed do
    begin
      InStream := GetCurrentInStream(Socket);
      if not Assigned(InStream) then
        begin
          InStream := CreateInStream;
          SetCurrentInStream(Socket, InStream);
        end;
      try
        ReadPos := ReadPos + InStream.Write(FReadBuffer[ReadPos], Readed - ReadPos);
      except
        on e: Exception do
          begin
            PostMessage(Socket.Handle, CM_SOCKETMESSAGE, Socket.SocketHandle, MakeLParam(FD_CLOSE, 0));
            exit;
          end;
      end;

      if InStream.Complete then
        begin
          InStream.Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
          tmpStream := InStream;
          SetCurrentInStream(Socket, nil);
          FDeferredReceiveItems.AddNew(Socket, tmpStream);
		  {$IFDEF DontAvoidDeferredReceive}
          PostMessage(FWndHandle, WM_DEFERRED_RECEIVE, 0, 0);
		  {$ELSE}
		  SendMessage(FWndHandle, WM_DEFERRED_RECEIVE, 0, 0);
		  {$ENDIF}
        end;
    end;
end;

procedure TAbstractDataTransfer.OnWrite(Sender: TObject; Socket: TCustomWinSocket);
var
  OutDataList: TObjectList;
  Stream: TStream;
  Readed, Writed: Integer;
begin
  OutDataList := GetOutDataList(Socket);
  if not Assigned(OutDataList) then
    exit;
  Stream := nil;
  while true do
    begin
      if OutDataList.Count > 0 then
        Stream := TStream(OutDataList.Items[0])
      else
        break;
      // определились с текущим потоком на передачу.
      Readed := Stream.Read(FOutBuffer[0], SocketBuffSize);
      // считали из него в передающий буфер
      if Readed = 0 then
        begin
          // если ничего не считалось - значит передача этого потока
          // закончилась. Удалим его и возьмем следующий.
          OutDataList.Delete(0);
          Continue;
        end;

      // отправляем данные в сокет
      try
        Writed := Socket.SendBuf(FOutBuffer[0], Readed);
      except
        Writed := -1;
        PostMessage(Socket.Handle, CM_SOCKETMESSAGE, Socket.SocketHandle, MakeLParam(FD_CLOSE, 0));
      end;

      // передастся не обязательно столько данных, сколько мы "заказали" -
      // буфер сокета может быть забит предыдущими отправленными нами данными
      // которые еще не успели уйти в сеть.
      // посему - передвигаем указатель Stream-а на количество байт,
      // реально отправленных в буфер сокета (не путать буфер сокета с FOutBuffer - это наш
      // собственный внутренний буфер на передачу
      if Writed = -1 then
        begin
          // если ничего передать не удалось, значит буфер сокета забит нами под завязку,
          // пора выходить отсюда.
          // когда он освободится, опять возникнет это событие (OnWrite)
          Stream.Seek(-Readed, {$IFDEF UseNewSeek}soCurrent{$ELSE}soFromCurrent{$ENDIF});
          break;
        end
      else
        if Writed < Readed then
          begin
            // в сокет передалось меньше, чем мы пытались. Передвигаем указатель
            // потока "назад" на количество переданных байт
            Stream.Seek(Writed - Readed, {$IFDEF UseNewSeek}soCurrent{$ELSE}soFromCurrent{$ENDIF});
            // и тоже выходим - раз передалось не все, то буфер сокета забит "под завязку".
            break;
          end;
    end;
end;

procedure TAbstractDataTransfer.SetActive(const Value: Boolean);
begin
  FActive := Value;
end;

procedure TAbstractDataTransfer.SetTCPPort(const Value: Integer);
begin
  FTCPPort := Value;
end;

procedure TAbstractDataTransfer.WndProc(var message: TMessage);
var
  Socket: TCustomWinSocket;
  Stream: TStream;
begin
  case message.Msg of
    WM_DEFERRED_RECEIVE:
      begin
        if not FInReceive then // avoid nested calls by Application.ProcessMessages
          begin
            FInReceive := true;
            try
              while FDeferredReceiveItems.ExtractFirst(Socket, Stream) do
                DoReceiveData(Socket, Stream);
            finally
              FInReceive := False;
            end;
          end;
      end;
  else
    message.Result := DefWindowProc(FWndHandle, message.Msg, message.WParam, message.LParam);
  end;
end;

end.
