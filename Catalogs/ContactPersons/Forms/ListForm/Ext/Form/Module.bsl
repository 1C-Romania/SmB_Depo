
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Processes a row activation event of the document list.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	InfPanelParameters = New Structure("CIAttribute, ContactPerson", "Ref");
	SmallBusinessClient.InfoPanelProcessListRowActivation(ThisForm, InfPanelParameters);
	
EndProcedure // HandleListStringActivation()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	ContactPersonsListByDefault = GetContactPersonsByDefault();
	
	If ContactPersonsListByDefault.Count() > 0 Then
		
		SetAppearanceOfContactPersonsByDefault(ContactPersonsListByDefault);
		
	EndIf;
	
	If Parameters.Property("OpeningMode") Then
		WindowOpeningMode = Parameters.OpeningMode;
	EndIf;
	
	If Users.InfobaseUserWithFullAccess()
		OR (IsInRole("OutputToPrinterClipboardFile")
		AND EmailOperations.CheckSystemAccountAvailable()) Then
		
		SystemEmailAccount = EmailOperations.SystemAccount();
		
	Else
		
		Items.ListDetailsContactPersonEmailAddress.Hyperlink = False;
		
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtServerNoContext
// Function receives and returns a contact person selection default 
// 
// ArrayCounterparty - counterparty array for which it is required to select contact persons default.
//
Function GetContactPersonsByDefault(ArrayCounterparty = Undefined)
	
	Query			= New Query;
	
	Query.Text	=
	"SELECT
	|	Counterparties.ContactPerson AS ContactPerson
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	(NOT Counterparties.IsFolder)
	|	AND (NOT Counterparties.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef))
	|	AND &FilterConditionByCounterparties";
	
	
	Query.Text = StrReplace(Query.Text, 
		"&FilterConditionByCounterparties",
		?(TypeOf(ArrayCounterparty) = Type("Array"), "Counterparties.Ref IN (&ArrayCounterparty)", "True"));
	
	QueryResult			= Query.Execute().Unload();
	
	ContactPersonsListByDefault	= New ValueList;
	ContactPersonsListByDefault.LoadValues(QueryResult.UnloadColumn("ContactPerson"));
	
	Return ContactPersonsListByDefault;
	
EndFunction //GetContactPersonsByDefault()

&AtServer
// Procedure selects in contact person list by bold font default
//
Procedure SetAppearanceOfContactPersonsByDefault(ContactPersonsListByDefault)
	
	//  CLEAN
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		
		If ConditionalAppearanceItem.UserSettingID = "Preset" Then
			
			List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(ConditionalAppearanceItem);
			
		EndIf;
		
	EndDo;
	
	//  COLORIZE
	ConditionalAppearanceItemsOfList	= List.SettingsComposer.Settings.ConditionalAppearance.Items;
	ConditionalAppearanceItem			= ConditionalAppearanceItemsOfList.Add();
	
	FilterItem 						= ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue 		= New DataCompositionField("Ref");
	FilterItem.ComparisonType 			= DataCompositionComparisonType.InList;
	FilterItem.RightValue 		= ContactPersonsListByDefault;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(,,True,));
	
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = "Preset";
	ConditionalAppearanceItem.Presentation = "Contact person by default";  
	
EndProcedure //SetAppearanceOfContactPersonsByDefault()

&AtClient
// Procedure sets the current record as a default Contact person for the owner
//
Procedure SetAsContactPersonByDefault(Command)
	
	ContactPersonsListByDefault = New ValueList;
	
	CurrentListRow = Items.List.CurrentData;
	
	If CurrentListRow = Undefined Then
		
		MessageText = NStr("en = 'The contact person which is necessary to be set as a Contact person by default is not selected.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
		Return;
		
	EndIf;
	
	NewContactPerson	= CurrentListRow.Ref;
	Counterparty			= CurrentListRow.Owner;
	
	For Each ConditionalAppearanceItem IN List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		
		If ConditionalAppearanceItem.UserSettingID = "Preset" AND
			ConditionalAppearanceItem.Presentation = "Contact person by default" Then
			
			FilterItem					= ConditionalAppearanceItem.Filter.Items[0];
			ContactPersonsListByDefault	= FilterItem.RightValue;
			
			Break;
			
		EndIf;
		
	EndDo;
	
	If Not ContactPersonsListByDefault.FindByValue(NewContactPerson) = Undefined Then
		
		Return;
		
	EndIf;
	
	ChangeCardOfCounterpartyAndChangeListAppearance(Counterparty, NewContactPerson, ContactPersonsListByDefault);
	
	Notify("RereadContactPersonByDefault");
	
EndProcedure //SetAsContactPersonByDefault()

&AtServer
// Procedure - writes new value in
// counterparty card and updates the visual presentation of the contact person default in list form
//
Procedure ChangeCardOfCounterpartyAndChangeListAppearance(Counterparty, NewContactPerson, ContactPersonsListByDefault)
	
	CounterpartyObject 						= Counterparty.GetObject();
	OldContactPersonByDefault			= CounterpartyObject.ContactPerson;
	CounterpartyObject.ContactPerson			= NewContactPerson;
	
	Try
		
		CounterpartyObject.Write();
		
	Except
		
		MessageText = NStr("en = 'Failed to change the default contact person in the counterparty card.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndTry;
	
	ValueListItem 					= ContactPersonsListByDefault.FindByValue(OldContactPersonByDefault);
	
	If Not ValueListItem = Undefined Then
		
		ContactPersonsListByDefault.Delete(ValueListItem);
		
	EndIf;
	
	ContactPersonsListByDefault.Add(NewContactPerson);
	
	SetAppearanceOfContactPersonsByDefault(ContactPersonsListByDefault);
	
EndProcedure //ChangeCardOfCounterpartyAndChangeListAppearance()

// Procedure - handler of clicking the SendEmailToContactPerson button.
//
&AtClient
Procedure SendEmailToContactPerson(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(ContactPersonESInformation) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.Ref);
		StructureRecipient.Insert("Address", ContactPersonESInformation);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToContactPerson()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - DYNAMIC LIST EVENT HANDLERS

// Procedure - event handler OnActivateRow of dynamic list List.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	
EndProcedure // ListOnActivateRow()

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "CreatingFormContactPersons";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "OpeningFormContactPersons";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

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
