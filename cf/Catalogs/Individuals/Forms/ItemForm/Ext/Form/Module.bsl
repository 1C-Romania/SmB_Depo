
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetCurrentIndividualDocument();
	
	If Parameters.Key.IsEmpty() Then
		
		// SB.ContactInformation
		ContactInformationSB.OnCreateOnReadAtServer(ThisObject);
		// End SB.ContactInformation
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// SB.ContactInformation
	ContactInformationSB.OnCreateOnReadAtServer(ThisObject);
	// End SB.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	ElsIf EventName = "ChangedIndividualDocument" Then
		GetCurrentIndividualDocument();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// SB.ContactInformation
	ContactInformationSB.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End SB.ContactInformation
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// SB.ContactInformation
	ContactInformationSB.FillCheckProcessingAtServer(ThisObject, Cancel);
	// End SB.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogIndividualsWrite");
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_Individuals", Object.Ref)
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure DocumentClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If Object.Ref.IsEmpty() Then
		ButtonsList = New ValueList;
		ButtonsList.Add(DialogReturnCode.Yes, NStr("ru='Записать'; en = 'Write'"));
		ButtonsList.Add(DialogReturnCode.No, NStr("ru='Отмена'; en = 'Cancel'"));
		Notify = New NotifyDescription("NotifyProcessingGoingToDocuments", ThisObject);
		
		ShowQueryBox(
			Notify,
			NStr("ru='Переход к заполнению сведений документов возможен только после записи.
				|Записать?'; en = 'Go to filling the information document is only possible after write.
				|Write?'"),
			ButtonsList);
		
		Write();
		Return;
	EndIf;
	If Not Object.Ref.IsEmpty() Then
		No = New NotifyDescription("NotifyFillingDocument", ThisObject);
		OpenForm("InformationRegister.IndividualsDocuments.Form.FormFillingDetails",New Structure("Ind", Object.Ref),,,,,No, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure GetCurrentIndividualDocument()
	
	Document = InformationRegisters.IndividualsDocuments.GetDocumentPresentationByIndividual(Object.Ref);
	
EndProcedure

&AtClient
Procedure NotifyProcessingGoingToDocuments(Result,Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Write();
	Else
		Return;
	EndIf;
	
	If Not Object.Ref.IsEmpty() Then
		No = New NotifyDescription("NotifyFillingDocument", ThisObject);
		OpenForm("InformationRegister.IndividualsDocuments.Form.FormFillingDetails",New Structure("Ind", Object.Ref),,,,,No, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyFillingDocument(Result,Parameters) Export
	GetCurrentIndividualDocument();
EndProcedure

#EndRegion

#Region ContactInformationSB

&AtServer
Procedure AddContactInformationServer(AddingKind, SetShowInFormAlways = False) Export
	
	ContactInformationSB.AddContactInformation(ThisObject, AddingKind, SetShowInFormAlways);
	
EndProcedure

&AtClient
Procedure Attachable_ActionCIClick(Item)
	
	ContactInformationSBClient.ActionCIClick(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIOnChange(Item)
	
	ContactInformationSBClient.PresentationCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIStartChoice(Item, ChoiceData, StandardProcessing)
	
	ContactInformationSBClient.PresentationCIStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_PresentationCIClearing(Item, StandardProcessing)
	
	ContactInformationSBClient.PresentationCIClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_CommentCIOnChange(Item)
	
	ContactInformationSBClient.CommentCIOnChange(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationSBExecuteCommand(Command)
	
	ContactInformationSBClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
	
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()

// End StandardSubsystems.Properties

#EndRegion

