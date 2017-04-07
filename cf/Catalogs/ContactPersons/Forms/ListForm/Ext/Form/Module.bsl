
#Region FormVariables

&AtClient
Var SettingMainContactPersonCompleted; // Flag of successful setting of main contact person from a form of counterparty

#EndRegion

#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then
		Return; // Return if the form for analysis is received..
	EndIf;
	
	Parameters.Filter.Property("Owner", CounterpartyOwner);
	
	If ValueIsFilled(CounterpartyOwner) Then
		// Context opening of the form with the selection by the counterparty
	
		AutoTitle = False;
		Title = NStr("ru='Контактные лица'; en = 'Contact persons'") + " """ + CounterpartyOwner + """";
		
		List.Parameters.SetParameterValue("MainCounterpartyContactPerson",
			CommonUse.ObjectAttributeValue(CounterpartyOwner, "ContactPerson"));
		
	Else
		// Opening in common mode
		
		Items.Owner.Visible		= True;
		Items.MoveUp.Visible	= False;
		Items.MoveDown.Visible	= False;
		List.Parameters.SetParameterValue("MainCounterpartyContactPerson", Undefined);
		
	EndIf;
	
	Items.UseAsMain.Visible = AccessRight("Edit", Metadata.Catalogs.Counterparties);
	
	CommonUseClientServer.SetFilterDynamicListItem(
		List,
		"Invalid",
		False,
		,
		,
		Not Items.ShowInvalid.Check);
	
	// Establish the settings form for the case of the opening of the choice mode
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	Items.List.MultipleChoice = ?(Parameters.CloseOnChoice = Undefined, False, Not Parameters.CloseOnChoice);
	If Parameters.ChoiceMode Then
		PurposeUseKey = "ChoicePick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	Else
		PurposeUseKey = "List";
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingMainContactPersonCompleted" Then
		SettingMainContactPersonCompleted = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Items.List.CurrentRow) <> Type("DynamicalListGroupRow")
		And Items.List.CurrentData <> Undefined Then
		
		Items.UseAsMain.Enabled = Not Items.List.CurrentData.IsMainContactPerson;
	EndIf;
	
EndProcedure // ListOnActivateRow()

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UseAsMain(Command)
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicalListGroupRow")
		Or Items.List.CurrentData = Undefined
		Or Items.List.CurrentData.IsMainContactPerson Then
		
		Return;
	EndIf;
	
	NewMainContactPerson = Items.List.CurrentData.Ref;
	
	// If the form of counterparty is opened, then change the main account in it
	SettingMainContactPersonCompleted = False;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Counterparty", Items.List.CurrentData.Owner);
	ParametersStructure.Insert("NewMainContactPerson", NewMainContactPerson);
	
	Notify("SettingMainContactPerson", ParametersStructure, ThisObject);
	
	// If the form of counterparty is closed, then change the main account by ourselves
	If Not SettingMainContactPersonCompleted Then
		WriteMainContactPerson(ParametersStructure);
	EndIf;
	
	// Update dynamical list
	If ValueIsFilled(CounterpartyOwner) Then
		List.Parameters.SetParameterValue("MainCounterpartyContactPerson", NewMainContactPerson);
	Else
		Items.List.Refresh();;
	EndIf;
	
EndProcedure //UseAsMain()

&AtClient
Procedure ShowInvalid(Command)
	
	Items.ShowInvalid.Check = Not Items.ShowInvalid.Check;
	
	CommonUseClientServer.SetFilterDynamicListItem(
		List,
		"Invalid",
		False,
		,
		,
		Not Items.ShowInvalid.Check);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
	
&AtServer
Procedure SetConditionalAppearance()
	
	// 1. Invalid contact distinguish gray
	NewConditionalAppearance = List.SettingsComposer.FixedSettings.ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("TextColor");
	Appearance.Value 	= StyleColors.UnavailableCellTextColor;
	Appearance.Use		= True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType	= DataCompositionComparisonType.Equal;
	Filter.Use				= True;
	Filter.LeftValue 		= New DataCompositionField("Invalid");
	Filter.RightValue 		= True;
	
EndProcedure

&AtServerNoContext
Процедура WriteMainContactPerson(ParametersStructure)
	
	CounterpartyObject = ParametersStructure.Counterparty.GetObject();
	CounterpartySuccesfullyLocked = True;
	
	Try
		CounterpartyObject.Lock();
	Except
		
		CounterpartySuccesfullyLocked = False;
		
		MessageText = StrTemplate(
			NStr("ru = 'Не удалось заблокировать %1: %2, для изменения основного контактного лица, по причине:
				|%3'; en = 'Could not be locked %1: %2, for editing main contact person, because:
				|%3'", Metadata.DefaultLanguage.LanguageCode), 
				ParametersStructure.Counterparty.Metadata.ObjectPresentation, DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(MessageText, EventLogLevel.Warning,, CounterpartyObject, ErrorDescription());
		
	EndTry;
	
	// If lockig was successful edit bank account by default of counterparty
	If CounterpartySuccesfullyLocked Then
		CounterpartyObject.ContactPerson = ParametersStructure.NewMainContactPerson;
		CounterpartyObject.Write();
	EndIf;
	
EndProcedure

#EndRegion

#Region LibraryHandlers
	
&AtClient
Procedure MoveUp(Command)
	ItemOrderSetupClient.MoveItemUpExecute(List, Items.List);
EndProcedure

&AtClient
Procedure MoveDown(Command)
	ItemOrderSetupClient.MoveItemDownExecute(List, Items.List);
EndProcedure

#EndRegion