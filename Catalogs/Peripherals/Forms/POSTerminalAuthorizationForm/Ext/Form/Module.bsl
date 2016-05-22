
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	ListOfCardTypes = Undefined;

	tempAmount = 0;
	If Parameters.Property("Amount", tempAmount)
	   AND tempAmount > 0 Then
		Amount = tempAmount;
	Else
		Amount = 0;
	EndIf;

	tempTimeLimit = 0;
	If Parameters.Property("LimitAmount", tempTimeLimit)
	   AND tempTimeLimit > 0 Then
		Items.Amount.MaxValue = tempTimeLimit;
	Else
		Items.Amount.MaxValue = Undefined;
	EndIf;
	
	If Parameters.Property("AmountEditingProhibition") Then
		Items.Amount.ReadOnly = Parameters.AmountEditingProhibition;
	EndIf;
	
	If Parameters.Property("ListOfCardTypes", ListOfCardTypes)
	   AND TypeOf(ListOfCardTypes) = Type("ValueList")
	   AND ListOfCardTypes. Count() > 0 Then
		For Each ListRow IN ListOfCardTypes Do
			Items.CardType.ChoiceList.Add(ListRow.Value, ListRow.Presentation);
		EndDo;
		Items.CardType.Visible = True;
	EndIf;
	
	Items.CardNumber.Visible  = False;
	Items.CardNumber.ReadOnly = True;
	Items.CardNumber.TextEdit = False;

	If Parameters.Property("ShowCardNumber", ShowCardNumber) Then
		If ShowCardNumber Then
			Items.CardNumber.Visible  = True;
			Items.CardNumber.ReadOnly = False;
			Items.CardNumber.TextEdit = True;
		EndIf;
	EndIf;
	
	If Items.Amount.ReadOnly Then
		Items.Amount.DefaultControl = False;
		If Items.CardType.Visible AND Items.CardType.ChoiceList.Count() > 1 Then
			Items.CardType.DefaultControl = True;
		ElsIf Items.CardNumber.Visible Then
			Items.CardNumber.DefaultControl = True;
		Else
			Items.RunOperation.DefaultControl = True;
		EndIf;
	EndIf;
	
	If Parameters.Property("SpecifyAdditionalInformation") Then
		SpecifyAdditionalInformation = True;
	EndIf;
	
	TypesOfPeripheral = EquipmentManagerServerReUse.TypesOfPeripheral();
	
	AvailableReadingOnMCR = ShowCardNumber AND (TypesOfPeripheral <> Undefined)
		AND (TypesOfPeripheral.Find(Enums.PeripheralTypes.MagneticCardReader) <> Undefined);
		
	Items.GroupManualDataInput.Visible = SpecifyAdditionalInformation;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If AvailableReadingOnMCR Then
		// Check and connect MC readers.
		SupportedTypesOfPeripherals = New Array();
		SupportedTypesOfPeripherals.Add("MagneticCardReader");
		If EquipmentManagerClient.ConnectEquipmentByType(UUID, SupportedTypesOfPeripherals) Then
			Items.LabelAvailableReadingOnMCR.Visible = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If AvailableReadingOnMCR Then
		// MC reader exit
		SupportedTypesOfPeripherals = New Array();
		SupportedTypesOfPeripherals.Add("MagneticCardReader");
		EquipmentManagerClient.DisableEquipmentByType(UUID, SupportedTypesOfPeripherals);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "TracksData" Then
			If Parameter[1] = Undefined Then
				CardCodeReceived(Parameter[0], Parameter[0]);
			Else
				CardCodeReceived(Parameter[0], Parameter[1][1]);
			EndIf;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
	If IsInputAvailable() Then
		
		DetailsEvents = New Structure();
		ErrorDescription  = "";
		DetailsEvents.Insert("Source", Source);
		DetailsEvents.Insert("Event",  Event);
		DetailsEvents.Insert("Data",   Data);
		
		Result = EquipmentManagerClient.GetEventFromDevice(DetailsEvents, ErrorDescription);
		If Result = Undefined Then 
			MessageText = NStr("en = 'An error occurred during the processing of external event from the device:'")
								+ Chars.LF + ErrorDescription;
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			NotificationProcessing(Result.EventName, Result.Parameter, Result.Source);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SpecifyAdditionalInformationOnChange(Item)

	Items.GroupManualDataInput.Visible = SpecifyAdditionalInformation;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RunOperation(Command)
	
	Errors = "";
	
	ClearMessages();
	
	If Amount = 0 Then
		Errors = NStr("en='Payment can not be performed for the amount equal to zero.'");
	EndIf;
	
	If ShowCardNumber AND Not ValueIsFilled(CardNumber) Then
		Errors = Errors + ?(IsBlankString(Errors),"",Chars.LF) + NStr("en='Payment can not be performed without number of card.'");
	EndIf;
	
	If IsBlankString(Errors) Then
		If Not SpecifyAdditionalInformation Then
			RefNo = "";
			ReceiptNumber      = "";
		EndIf;
		
		ReturnStructure = New Structure("Amount, CardData, RefNo, ReceiptNumber, CardType, CardNumber",
											Amount, CardData, RefNo, ReceiptNumber, CardType, CardNumber);
		ClearMessages();
		Close(ReturnStructure);
		
	Else
		CommonUseClientServer.MessageToUser(Errors,,"CardNumber");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function CardCodeReceived(CardCode, TracksData)

	If TypeOf(TracksData) = Type("Array")
	   AND TracksData.Count() > 1
	   AND TracksData[1] <> Undefined
	   AND Not IsBlankString(TracksData[1]) Then
		CardData = TracksData[1];

		SeparatorPosition = Find(CardData, "=");
		If SeparatorPosition > 16 Then
			CardNumber = Left(CardData, SeparatorPosition - 1);
			Items.CardNumber.Visible = True;
		Else
			CommonUseClientServer.MessageToUser(NStr("en='Invalid card is specified or an error occurred while reading the card.
			|Repeat reading or read another card'"));
		EndIf;
	Else
		CommonUseClientServer.MessageToUser(NStr("en='Invalid card is specified or an error occurred while reading the card.
		|Repeat reading or read another card'"));
	EndIf;
	
	RefreshDataRepresentation();
	
	Return True;
	
EndFunction

&AtClient
Procedure AmountTextEditEnd(Item, Text, ChoiceData, StandardProcessing)

	If Items.Amount.MaxValue <> Undefined
	   AND Items.Amount.MaxValue < Number(Text) Then
	   
		StandardProcessing = False;
		StructureValues = New Structure;
		StructureValues.Insert("Warning", NStr("en = 'Payment amount by card exceeds required non cash payment.
		|Value will be changed to the maximum.'"));
		StructureValues.Insert("Value", Format(Items.Amount.MaxValue, "ND=15; NFD=2; NZ=0; NG=0; NN=1"));
		
		ValueList = New ValueList;
		ValueList.Add(StructureValues);
		ChoiceData = ValueList;
		
	EndIf;

EndProcedure

#EndRegion
