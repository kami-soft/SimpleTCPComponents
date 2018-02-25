unit uPacketStream;
{$I SimpleTCPComponents.inc}
interface

uses
  Classes;

type
  TPacketHeader = packed record
    DataID: integer;
    DataSize: Int64; // размер заголовка сюда не входит !!!
    IsHeader: boolean;
  end;

  TAbstractOutPacketStream = class(TMemoryStream)
  public
    procedure FillHeader(const DataID: integer; const IsHeader: boolean); virtual;
  end;

  TAbstractInPacketStream = class(TMemoryStream)
  protected
    function GetComplete: boolean; virtual; abstract;
  public
    property Complete: boolean read GetComplete;
  end;

  TOutPacketStream = class(TAbstractOutPacketStream)
    // этот поток предназначен для передачи
    // пакета корреспонденту
    // соответственно - при создании ему сообщается
    // заголовок, метод Write записывает данные во "внутренний поток".
    // метод Read выдает данные, считая заголовок их первой частью.
  private
    FPos: Int64;
  strict protected
    FPacketHeader: TPacketHeader;
  protected
    procedure DoHeaderPrepared; virtual;
  public
    constructor Create;
    function Read(var Buffer; Count: Longint): Longint; override;
{$IFDEF UseNewSeek}
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
{$ELSE}
    function Seek(Offset: integer; Origin: Word): integer; override;
{$ENDIF}
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);

    procedure FillHeader(const DataID: integer; const IsHeader: boolean); override;
    procedure Clear;

    property PacketHeader: TPacketHeader read FPacketHeader write FPacketHeader;
  end;

  TInPacketStream = class(TAbstractInPacketStream)
    // здесь наоборот - запись производится начиная с заголовка
    // и сам поток регулирует, сколько данных он "заберет" на основании
    // DataSize
  private
    FPos: Int64;
  strict protected
    FPacketHeader: TPacketHeader;
  protected
    function GetComplete: boolean; override;
    procedure DoHeaderReceived; virtual;
  public
    constructor Create;
    function Write(const Buffer; Count: Longint): Longint; override;
{$IFDEF UseNewSeek}
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
{$ELSE}
    function Seek(Offset: integer; Origin: Word): integer; override;
{$ENDIF}
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);
    procedure Clear;
    property PacketHeader: TPacketHeader read FPacketHeader;
  end;

type
  TXMLChar = AnsiChar;
  TXMLString = AnsiString;
  PXMLString = PAnsiChar;

type
  TOutPacketStreamXML = class(TAbstractOutPacketStream)
    // этот поток предназначен для передачи
    // пакета корреспонденту
    // соответственно - при создании метод Write записывает данные во "внутренний поток".
    // метод Read выдает данные
  public
    procedure SaveAnsiXML(XML: TXMLString);
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

  TInPacketStreamXML = class(TAbstractInPacketStream)
    // здесь наоборот - запись производится начиная с заголовка
    // и сам поток регулирует, сколько данных он "заберет"
  private
    FRootTag: TXMLString;
    FComplete: boolean;
  protected
    function GetComplete: boolean; override;
  public
    constructor Create;
    function Write(const Buffer; Count: Longint): Longint; override;
{$IFDEF UseNewSeek}
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
{$ELSE}
    function Seek(Offset: integer; Origin: Word): integer; override;
{$ENDIF}
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);
  end;

  TOutPacketStreamClass = class of TAbstractOutPacketStream;
  TInPacketStreamClass = class of TAbstractInPacketStream;

implementation

uses
  Windows,
  SysUtils,
  System.AnsiStrings;

{$IFDEF LIMIT_PACKET_SIZE}

const
  MAX_PACKET_SIZE = 65535;
{$ENDIF}

function Min(const A, B: integer): integer; inline;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

{ TOutPacketStream }

procedure TOutPacketStream.Clear;
begin
  // FPacketHeader.DataID := 0;
  FPacketHeader.DataSize := 0;
  Size := 0;
  FPos := 0;
end;

constructor TOutPacketStream.Create;
begin
  inherited Create;
  FPos := 0;
end;

procedure TOutPacketStream.DoHeaderPrepared;
begin

end;

procedure TOutPacketStream.FillHeader(const DataID: integer; const IsHeader: boolean);
begin
  FPacketHeader.DataSize := inherited Seek(0, {$IFDEF UseNewSeek}soEnd{$ELSE}soFromEnd{$ENDIF});
  DoHeaderPrepared;
  // FPacketHeader.DataID := DataID;
  // FPacketHeader.IsHeader := IsHeader;
  inherited;
end;

procedure TOutPacketStream.LoadFromFile(const FileName: string);
begin
  raise EStreamError.Create('В TOutPacketStream невозможно чтение из файла');
end;

procedure TOutPacketStream.LoadFromStream(Stream: TStream);
begin
  raise EStreamError.Create('В TOutPacketStream невозможно чтение из потока');
end;

function TOutPacketStream.Read(var Buffer; Count: integer): Longint;
var
  Pb: PAnsiChar;
begin
  Result := 0;
  if Count > 0 then
    begin
      Pb := @Buffer;
      if FPos < sizeof(TPacketHeader) then
        begin
          Result := Min(Count, sizeof(TPacketHeader) - FPos);
          // Move(PAnsiChar(@FPacketHeader)[FPos], Pb^, Result);
          CopyMemory(Pb, @PAnsiChar(@FPacketHeader)[FPos], Result);
          Dec(Count, Result);
        end;
      if Count > 0 then
        Result := Result + inherited read(Pb[Result], Count);
      Inc(FPos, Result);
    end;
end;
{$IFDEF UseNewSeek}

function TOutPacketStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  case Origin of
    soBeginning:
      FPos := Offset;
    soCurrent:
      Inc(FPos, Offset);
    soEnd:
      FPos := Int64(sizeof(TPacketHeader)) + inherited Seek(0, soEnd) - Offset;
  end;
  if FPos < 0 then
    FPos := 0;
  Result := FPos;
  if Result >= sizeof(TPacketHeader) then
    inherited Seek(Result - sizeof(TPacketHeader), soBeginning)
  else
    inherited Seek(0, soBeginning);
end;
{$ELSE}

function TOutPacketStream.Seek(Offset: integer; Origin: Word): integer;
begin
  case Origin of
    soFromBeginning:
      FPos := Offset;
    soFromCurrent:
      Inc(FPos, Offset);
    soFromEnd:
      FPos := integer(sizeof(FPacketHeader)) + inherited Seek(0, soFromEnd) - Offset;
  end;
  if FPos < 0 then
    FPos := 0;
  Result := FPos;
  if Result >= sizeof(FPacketHeader) then
    inherited Seek(Result - sizeof(FPacketHeader), soFromBeginning)
  else
    inherited Seek(0, soFromBeginning);
end;
{$ENDIF}
{ TInPacketStream }

procedure TInPacketStream.Clear;
begin
  Size := 0;
  FPos := 0;
end;

constructor TInPacketStream.Create;
begin
  inherited Create;
  FPos := 0;

  // FPacketHeader.DataID := 0;
  FPacketHeader.DataSize := 0;
end;

procedure TInPacketStream.DoHeaderReceived;
begin

end;

function TInPacketStream.GetComplete: boolean;
begin
  Result := FPos = sizeof(TPacketHeader) + FPacketHeader.DataSize;
  if FPos > (sizeof(TPacketHeader) + FPacketHeader.DataSize) then
    raise EInOutError.Create('Ошибка при приеме пакета в сокете');
end;

procedure TInPacketStream.LoadFromFile(const FileName: string);
begin
  raise EStreamError.Create('В TInPacketStream невозможно чтение из файла');
end;

procedure TInPacketStream.LoadFromStream(Stream: TStream);
begin
  raise EStreamError.Create('В TInPacketStream невозможно чтение из потока');
end;
{$IFDEF UseNewSeek}

function TInPacketStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := 0;
  if not Complete then
    EStreamError.Create('Невозможно изменение позиции до полного приема пакета')
  else
    Result := inherited Seek(Offset, Origin);
end;
{$ELSE}

function TInPacketStream.Seek(Offset: integer; Origin: Word): integer;
begin
  Result := 0;
  if not Complete then
    EStreamError.Create('Невозможно изменение позиции до полного приема пакета')
  else
    Result := inherited Seek(Offset, Origin);
end;
{$ENDIF}

function TInPacketStream.Write(const Buffer; Count: integer): Longint;
var
  Pb: PAnsiChar;
begin
  Result := 0;
  if (Count <= 0) then
    raise EInOutError.Create('Ошибка TInPacketStream - неверная попытка записи. Невозможно записать count=' + IntToStr(Count));
  if Complete then
    begin
      raise EInOutError.Create('Ошибка TInPacketStream - неверная попытка записи. поток закрыт. FDataSize=' + IntToStr(FPacketHeader.DataSize) + ' FPos = ' +
        IntToStr(FPos) + ' HeaderSize = ' + IntToStr(sizeof(TPacketHeader)) + '  пытаемся записать ' + IntToStr(Count));
    end;
  Pb := @Buffer;
  if FPos < sizeof(TPacketHeader) then
    begin
      Result := Min(Count, sizeof(TPacketHeader) - FPos);
      // Move(Pb^, PAnsiChar(@FPacketHeader)[FPos], Result);
      CopyMemory(@PAnsiChar(@FPacketHeader)[FPos], Pb, Result);
      Dec(Count, Result);
      Inc(FPos, Result);
      if FPos = sizeof(TPacketHeader) then
        DoHeaderReceived;
    end;
  if Count > 0 then
    begin
{$IFDEF LIMIT_PACKET_SIZE}
      if FPacketHeader.DataSize > MAX_PACKET_SIZE then
        raise EInOutError.Create('Размер пакета превышает допустимый');
{$ENDIF}
      if not Complete then
        begin
          Count := Min(Count, FPacketHeader.DataSize - (FPos - sizeof(TPacketHeader)));
          Result := Result + inherited write(Pb[Result], Count);
          Inc(FPos, Count);
        end;
    end;
end;

function myAnsiStrPos(substr, str: PXMLString; FromStrPos, SubStrLen, StrLen: integer): integer;
var
  iPos: integer;
begin
  Result := -1;
  iPos := FromStrPos;
  Dec(StrLen, SubStrLen - 1);
  while iPos < StrLen do
    if System.AnsiStrings.AnsiStrLIComp(substr, @str[iPos], SubStrLen) = 0 then
      begin
        Result := iPos;
        Break;
      end
    else
      Inc(iPos);
end;

function TryGetCloseRootTag(str: PXMLString; LenStr: integer): TXMLString;
var
  iPos, iPos1: integer;
  tmpPXML: PXMLString;
begin
  Result := '';
  iPos := myAnsiStrPos('<', str, 0, 1, LenStr);
  if iPos = -1 then
    Exit;
  // нужно найти открывающий рут-тег. При этом - пропустить все служебные заголовки,
  // которые имеют вид <?xml version="1.0" encoding="cp1251"?>. Кстати, заголовков может и не быть
  // нужно задать ограничение на общий объем принимаемых данных.
  // а то может получиться, что открываем <?, пишем белиберду и программа сваливается.

  // пропускаем все служебные заголовки
  tmpPXML := @str[iPos];
  if System.AnsiStrings.AnsiStrLIComp('<?', tmpPXML, 2) = 0 then
    begin
      iPos := myAnsiStrPos('?>', str, iPos, 2, LenStr);
      if iPos = -1 then
        Exit;
      // теперь iPos указывает на закрывающие ?>
      Inc(iPos, 2); // а теперь - на символ после ?>
    end;

  if iPos >= (LenStr - 1) then
    Exit;

  // пропустили служебный заголовок, ищем root-тег
  iPos := myAnsiStrPos('<', str, iPos, 1, LenStr);
  if iPos = -1 then
    Exit;
  // нашли открывающий < от root - тега. Ищем закрывающий.
  iPos1 := myAnsiStrPos('>', str, iPos, 1, LenStr);
  if iPos1 = -1 then
    Exit;

  if iPos1 = (iPos + 1) then
    raise EInOutError.Create('Ошибка при приеме - root-тег не может быть пустым!!!');

  // копируем найденный root-тег во внутренний буфер
  SetLength(Result, iPos1 - iPos + 2); // кроме закрывающего > "прогнозируем" внесение слеша
  Move(str[iPos], Result[1], sizeof(TXMLChar));
  Result[2] := '/';
  Move(str[iPos + sizeof(TXMLChar)], Result[3], (iPos1 - iPos) * sizeof(TXMLChar));
end;

{ TInPacketStreamXML }

constructor TInPacketStreamXML.Create;
begin
  inherited Create;
  FRootTag := '';
end;

function TInPacketStreamXML.GetComplete: boolean;
var
  tmpBuf: PXMLString;
  iPos: integer;
  iLen: integer;
begin
  Result := FComplete;
  if Result then
    Exit;

  iPos := inherited Seek(0, {$IFDEF UseNewSeek}soCurrent{$ELSE}soFromCurrent{$ENDIF});
  iLen := (inherited Seek(0, {$IFDEF UseNewSeek}soEnd{$ELSE}soFromEnd{$ENDIF})) div sizeof(TXMLChar);
  inherited Seek(iPos, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});

  if iLen < 7 then // для валидного xml документа нужно как минимум <t></t>
    Exit;

  tmpBuf := Memory;
  // пропускаем всё до открывающей <
  if FRootTag = '' then
    FRootTag := TryGetCloseRootTag(tmpBuf, iLen);

  if FRootTag = '' then
    Exit;

  // есть закрывающий рут-тег. Пробуем найти его
  iPos := myAnsiStrPos(PXMLString(FRootTag), tmpBuf, 1, Length(FRootTag), iLen);
  Result := iPos <> -1;
end;

procedure TInPacketStreamXML.LoadFromFile(const FileName: string);
begin
  raise EStreamError.Create('В TInPacketStreamXML невозможно чтение из файла');
end;

procedure TInPacketStreamXML.LoadFromStream(Stream: TStream);
begin
  raise EStreamError.Create('В TInPacketStreamXML невозможно чтение из потока');
end;
{$IFDEF UseNewSeek}

function TInPacketStreamXML.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  if not Complete then
    raise EStreamError.Create('Невозможно изменение позиции до полного приема пакета')
  else
    Result := inherited Seek(Offset, Origin);
end;
{$ELSE}

function TInPacketStreamXML.Seek(Offset: integer; Origin: Word): integer;
begin
  if not Complete then
    raise EStreamError.Create('Невозможно изменение позиции до полного приема пакета')
  else
    Result := inherited Seek(Offset, Origin);
end;
{$ENDIF}

function TInPacketStreamXML.Write(const Buffer; Count: integer): Longint;
var
  i: integer;
  iSize: integer;
begin
  i := inherited Seek(0, {$IFDEF UseNewSeek}soCurrent{$ELSE}soFromCurrent{$ENDIF});
  iSize := inherited Seek(0, {$IFDEF UseNewSeek}soEnd{$ELSE}soFromEnd{$ENDIF});
  inherited Seek(i, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});

{$IFDEF LIMIT_PACKET_SIZE}
  if iSize > MAX_PACKET_SIZE then
    raise EInOutError.Create('Размер пакета превышает допустимый');
{$ENDIF}
  if (Count <= 0) then
    raise EInOutError.Create('Ошибка TInPacketStreamXML - неверная попытка записи');
  if Complete then
    raise EInOutError.Create('Ошибка TInPacketStreamXML - неверная попытка записи 1');

  Result := inherited write(Buffer, Count);

  Inc(iSize, Count);

  if Complete then
    begin
      i := myAnsiStrPos(PXMLString(FRootTag), Memory, 1, Length(FRootTag), iSize div sizeof(TXMLChar));
      Inc(i, Length(FRootTag));
      i := i * sizeof(TXMLChar);
      Result := Count - (iSize - i);
      Size := i;
    end;
end;

{ TOutPacketStreamXML }

procedure TOutPacketStreamXML.SaveAnsiXML(XML: TXMLString);
begin
  if XML <> '' then
    write(XML[1], Length(XML) * sizeof(TXMLChar));
end;

function TOutPacketStreamXML.Write(const Buffer; Count: integer): Longint;
begin
{$IFDEF LIMIT_PACKET_SIZE}
  if (inherited Size) > MAX_PACKET_SIZE then
    raise EInOutError.Create('Размер пакета превышает допустимый')
  else
{$ENDIF}
    Result := inherited write(Buffer, Count);
end;

{ TAbstractOutPacketStream }

procedure TAbstractOutPacketStream.FillHeader(const DataID: integer; const IsHeader: boolean);
begin
  Seek(0, {$IFDEF UseNewSeek}soBeginning{$ELSE}soFromBeginning{$ENDIF});
end;

end.
