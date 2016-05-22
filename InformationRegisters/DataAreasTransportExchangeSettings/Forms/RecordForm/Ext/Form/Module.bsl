
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	SetFormItemsVisible();
	
	If ValueIsFilled(Record.ExchangeMessageTransportKindByDefault) Then
		
		PageName = "TransportSettings[TransportKind]";
		PageName = StrReplace(PageName, "[TransportKind]"
		, CommonUse.NameOfEnumValue(Record.ExchangeMessageTransportKindByDefault));
		
		If Items[PageName].Visible Then
			
			Items.TransportKindPages.CurrentPage = Items[PageName];
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FILEInformationExchangeDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "FILEInformationExchangeDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure FILEInformationExchangeDirectoryOpening(Item, StandardProcessing)
	
	DataExchangeClient.HandlerOfOpeningOfFileOrDirectory(Record, "FILEInformationExchangeDirectory", StandardProcessing)
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CheckFILEConnection(Command)
	
	CheckConnection("FILE");
	
EndProcedure

&AtClient
Procedure CheckConnectionFTP(Command)
	
	CheckConnection("FTP");
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CheckConnection(TransportKindString)
	
	Cancel = False;
	
	ClearMessages();
	
	CheckConnectionAtServer(Cancel, TransportKindString);
	
	WarningText = ?(Cancel, NStr("en = 'Failed to install connection.'"), NStr("en = 'Connection has been successfully installed.'"));
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtServer
Procedure CheckConnectionAtServer(Cancel, TransportKindString)
	
	DataExchangeServer.CheckConnectionOfExchangeMessagesTransportDataProcessor(Cancel, Record, Enums.ExchangeMessagesTransportKinds[TransportKindString]);
	
EndProcedure

&AtServer
Procedure SetFormItemsVisible()
	
	UsedTransports = New Array;
	UsedTransports.Add(Enums.ExchangeMessagesTransportKinds.FILE);
	UsedTransports.Add(Enums.ExchangeMessagesTransportKinds.FTP);
	
	Items.ExchangeMessageTransportKindByDefault.ChoiceList.Clear();
	
	For Each Item IN UsedTransports Do
		
		Items.ExchangeMessageTransportKindByDefault.ChoiceList.Add(Item, String(Item));
		
	EndDo;
	
EndProcedure

#EndRegion
