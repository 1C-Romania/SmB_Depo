&AtClient
Var ExternalAttachableModule;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Storages <> Undefined Then
		For Each Storage IN Parameters.Storages Do
			Items.StorageIdentifier.ChoiceList.Add(Storage);
		EndDo;
		
		If Parameters.Storages.Count() = 1 Then
			Items.StorageIdentifier.Enabled = False;
			CurrentItem = Items.Pin;
		EndIf;
	EndIf;

	
	BankApplication = CommonUse.ObjectAttributeValue(Parameters.EDAgreement, "BankApplication");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
		ExternalAttachableModule = ElectronicDocumentsServiceClient.ExternalConnectedModuleThroughAdditionalDataProcessor(
																										Parameters.EDAgreement);
		If ExternalAttachableModule = Undefined Then
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
	SetEnabledOfItems();
		
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure StorageOnChange(Item)

	SetEnabledOfItems();
	Pin = "";
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Done(Command)
	
	If Not ValueIsFilled(StorageIdentifier) Then
		CommonUseClientServer.MessageToUser(NStr("en='Storage is not selected';ru='Не выбрано хранилище'"), , "StorageIdentifier");
		Return;
	EndIf;
	
	If Items.Pin.Enabled Then
		If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			PinCodeSet = ElectronicDocumentsServiceClient.SetStoragePINCodeThroughAdditionalDataProcessor(
																ExternalAttachableModule, StorageIdentifier, Pin)
		Else
			PinCodeSet = ElectronicDocumentsServiceClient.SetStoragePINCodeiBank2(StorageIdentifier, Pin);
		EndIf;
	Else
		PinCodeSet = True;
	EndIf;
	
	If PinCodeSet Then
		Close(StorageIdentifier);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetEnabledOfItems()

	If ValueIsFilled(StorageIdentifier) Then
	
		If BankApplication = PredefinedValue("Enum.BankApplications.ExchangeThroughTheAdditionalInformationProcessor") Then
			Items.Pin.Enabled = ElectronicDocumentsServiceClient.RequiredToSetStoragePINCodeThroughAdditionalDataProcessor(ExternalAttachableModule, StorageIdentifier) = True
				AND Not ElectronicDocumentsServiceClient.StoragePINCodeIsSetThroughAdditionalDataProcessor(ExternalAttachableModule, StorageIdentifier) = True;
		Else
			Items.Pin.Enabled = ElectronicDocumentsServiceClient.RequiredToSetStoragePINCodeiBank2(StorageIdentifier) = True;
		EndIf;
	
	EndIf;

EndProcedure

#EndRegion















