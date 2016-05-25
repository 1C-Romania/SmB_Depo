////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.Responsible = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");	;
		Object.ConnectionRegistrationDate = CurrentDate();
	EndIf;
	
	If Users.InfobaseUserWithFullAccess()
		OR (IsInRole("OutputToPrinterClipboardFile")
		AND EmailOperations.CheckSystemAccountAvailable()) Then
		
		SystemEmailAccount = EmailOperations.SystemAccount();
		
	Else
		
		Items.FormSendEmailToContactPerson.Visible = False;
		
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnCreateAtServer(ThisForm, Object, "GroupContactInformation");
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

&AtServer
// Event handler procedure OnReadAtServer
//
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
	// Subsystem handler "Contact information".
	ContactInformationManagement.BeforeWriteAtServer(ThisForm, CurrentObject, Cancel);
	
EndProcedure // BeforeWriteAtServer()

&AtServer
// Procedure-handler of the FillCheckProcessingAtServer event.
//
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.ContactInformation
	ContactInformationManagement.FillCheckProcessingAtServer(ThisForm, Object, Cancel);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROPERTY MECHANISM PROCEDURES

////////////////////////////////////////////////////////////////////////////////
// SUBSYSTEM PROCEDURES "CONTACT INFORMATION"


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

// StandardSubsystems.ContactInformation
&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	
	ContactInformationManagementClient.PresentationOnChange(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	
	Result = ContactInformationManagementClient.PresentationStartChoice(ThisForm, Item, , StandardProcessing);
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	
	Result = ContactInformationManagementClient.ClearingPresentation(ThisForm, Item.Name);
	RefreshContactInformation(Result);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	
	Result = ContactInformationManagementClient.LinkCommand(ThisForm, Command.Name);
	RefreshContactInformation(Result);
	ContactInformationManagementClient.OpenAddressEntryForm(ThisForm, Result);
	
EndProcedure

&AtServer
Function RefreshContactInformation(Result = Undefined)
	
	Return ContactInformationManagement.RefreshContactInformation(ThisForm, Object, Result);
	
EndFunction

#Region SB_KI
&AtServerNoContext
Function GetEMAILContactPerson(RefToCurrentItem)
	
	If RefToCurrentItem = Catalogs.ContactPersons.EmptyRef() Then
		
		Return Undefined;
		
	EndIf;
	
	Result = New Array;
	MailAddressArray = New Array;
	StructureRecipient = New Structure("Presentation, Address", RefToCurrentItem);
	
	Query = New Query;
	Query.SetParameter("Ref", RefToCurrentItem);
	
	Query.Text =
	"SELECT
	|	ContactPersonsContactInformation.Ref.Description AS ContactPresentation,
	|	ContactPersonsContactInformation.EMail_Address AS EMail_Address
	|FROM
	|	Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
	|WHERE
	|	ContactPersonsContactInformation.Ref = &Ref";
	
	SelectionFromQuery = Query.Execute().Select();
	AddContactEmailAddress = True;
	While SelectionFromQuery.Next() Do
		
		If Not ValueIsFilled(SelectionFromQuery.EMail_Address)
			OR (NOT AddContactEmailAddress) Then
			
			Continue;
			
		EndIf;
		
		If MailAddressArray.Find(SelectionFromQuery.EMail_Address) = Undefined Then
			
			MailAddressArray.Add(SelectionFromQuery.EMail_Address);
			AddCounterpartyEmailAddress = False;
			
		EndIf;
		
	EndDo;
	
	StructureRecipient.Address = StringFunctionsClientServer.GetStringFromSubstringArray(MailAddressArray, "; ");
	Result.Add(StructureRecipient);
	
	Return Result;
	
EndFunction // GetEMAILContactPerson()

&AtClient
Procedure SendEmailToContactPerson(Command)
	
	ListOfEmailAddresses = GetEMAILContactPerson(Object.Ref);
	
	If ListOfEmailAddresses = Undefined Then
		
		ListOfEmailAddresses = New ValueList;
		MessageText = NStr("en = 'Counterparty is not written. The list of emails will be empty.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	SendingParameters = New Structure("Recipient, DeleteFilesAfterSend", ListOfEmailAddresses, True);
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToContactPerson()
#EndRegion
// End StandardSubsystems.ContactInformation

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



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
