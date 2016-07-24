# SimpleTCPComponents


Classes - wrappers arount TClient|TServerSocket, works in Delphi5 - RAD X. 
Tested only in D2010, XE7, RAD X.

=============================================================================
Capabilities:
- transfer / receive data over a network with automated processing of the splitting/gluing packets
- data Queuing. ie, attempt to transfer large TStream will not lead to the transmission failure of the second and subsequent as with TClient/TServerSocket
- TDataTransferClient handling the disconnection with the resumption of data transfer after the connection is restored
- the data sent will come either fully (in one OnReceiveData event) or not coming at all

=============================================================================
Specific:
- when transferring, component becomes the owner of TStream and destroy it if necessary
- when receiving, the owner must destroy the received stream in OnReceiveData event


=============================================================================
  Классы-обертки над TClient|TServerSocket, работоспособны Delphi 2009 и выше (скорее всего - на Delphi7 и выше).
  Тестировалось на D2010, XE7, RAD X.
  
=============================================================================
  Возможности:
  - прием/передача информации по сети с автоматической обработкой
  разбиения/склейки пакетов
  - постановка данных в очередь на передачу (т.е. попытка передачи к примеру больших
  TStream не приведет к отказу передачи второго и последующих,
  как это было бы с TClient|ServerSocket
  - TDataTransferClient обеспечивает обработку разрыва соединения
  с возобновлением передачи данных после восстановления соединения.
  - отправленные данные либо придут ПОЛНОСТЬЮ (за ОДНО событие
  приема) либо не придут вообще.
  
=============================================================================
  Передача данных корреспонденту поддерживается несколькими методами
  (буфер, строка, TStream). Прием - только TStream. Для "перегона" из потока
  в строку добавлена процедура ReadStringFromStream.
  При необходимости - расширить на события с приемными буферами других типов
  несложно. У сервера есть методы "Передать всем" и "передать конкретному".
  
=============================================================================
  Ограничения:
  Не стоит (но не значит, что нельзя) передавать данные в несколько сотен мегабайт
  от сервера клиентам - внутреннее хранилище данных основано на TMemoryStream,
  что при наличии десятков подключений (при использовании методов "Передать всем")
  приведет к задействованию памяти SourceSize*ClientCount.
  
=============================================================================
  Особенности:
  При передаче данных через TStream сетевой компонент становится его владельцем
  и САМ уничтожит его. Посему - передали Stream в метод и ЗАБЫЛИ про него.
  При приеме - наоборот. Получив TStream из сетевого компонента,
  владелец ОБЯЗАН его уничтожить.
