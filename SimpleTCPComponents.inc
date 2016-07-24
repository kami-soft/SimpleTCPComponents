// остаток от версии, которая поддерживала Delphi 7
// при использовании версий Delphi, у которых метод TStream.Seek
// работает с параметрами soFromBeginning/soFromCurrent/soFromEnd -
{$IF CompilerVersion >= 17}
  {$DEFINE UseNewSeek}
{$IFEND}

{$IF CompilerVersion >=20}
  {$DEFINE EncodingPresented}
{$IFEND}

// ограничивать ли максимально возможную длину пакета на прием и передачу
// если раскомментировано - максимальный размер пакета
// задается константой MAX_PACKET_SIZE
{.$DEFINE LIMIT_PACKET_SIZE }

{$DEFINE DontAvoidDeferredReceive}

//  этот Define введен
//  для модифицированного мной модуля ScktComp, что позволило
//  привязывать сокеты к конкретным IP адресам и включать/отключать алгоритм Нагла.
//  Так как в комплект поставки этих компонентов модуль ScktComp не входит,
//  то попытка использовать эти функции ни к чему хорошему не приведут.

{.$DEFINE ExtScktComp}