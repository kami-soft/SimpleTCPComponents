object Form11: TForm11
  Left = 0
  Top = 0
  Caption = 'Form11'
  ClientHeight = 275
  ClientWidth = 554
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object spl1: TSplitter
    Left = 268
    Top = 0
    Height = 275
    ExplicitLeft = 296
    ExplicitTop = 64
    ExplicitHeight = 100
  end
  object grpServer: TGroupBox
    Left = 0
    Top = 0
    Width = 268
    Height = 275
    Align = alLeft
    Caption = 'grpServer'
    TabOrder = 0
    ExplicitLeft = -3
    ExplicitHeight = 242
    DesignSize = (
      268
      275)
    object edtSendFromServer: TEdit
      Left = 8
      Top = 32
      Width = 148
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
      ExplicitWidth = 145
    end
    object btnSendFromServer: TButton
      Left = 159
      Top = 30
      Width = 106
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'SendFromServer'
      TabOrder = 1
      OnClick = btnSendFromServerClick
      ExplicitLeft = 156
    end
    object mmoReceivedOnServer: TMemo
      Left = 2
      Top = 72
      Width = 264
      Height = 201
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      Lines.Strings = (
        'mmoReceivedOnServer')
      TabOrder = 2
      ExplicitHeight = 168
    end
  end
  object grpClient: TGroupBox
    Left = 271
    Top = 0
    Width = 283
    Height = 275
    Align = alClient
    Caption = 'grpClient'
    TabOrder = 1
    ExplicitLeft = 360
    ExplicitWidth = 167
    ExplicitHeight = 242
    DesignSize = (
      283
      275)
    object edtSendFromClient: TEdit
      Left = 6
      Top = 32
      Width = 155
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
    end
    object btnSendFromClient: TButton
      Left = 167
      Top = 30
      Width = 106
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'SendFromClient'
      TabOrder = 1
      OnClick = btnSendFromClientClick
    end
    object mmoReceivedOnClient: TMemo
      Left = 2
      Top = 72
      Width = 279
      Height = 201
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      Lines.Strings = (
        'mmoReceivedOnClient')
      TabOrder = 2
      ExplicitLeft = 4
      ExplicitTop = 74
    end
  end
end
