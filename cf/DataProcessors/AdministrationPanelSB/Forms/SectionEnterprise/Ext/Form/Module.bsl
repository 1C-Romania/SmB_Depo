
&AtClient
Var RefreshInterface;

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonUseClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		#If Not WebClient Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
		#EndIf
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	#If Not WebClient Then
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	#EndIf
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure // VisibleManagement()

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator 
		OR CommonUseReUse.CanUseSeparatedData() Then
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleCompanies" OR AttributePathToData = "" Then
			ConstantsSet.FunctionalOptionAccountingByMultipleCompanies = GetFunctionalOption("MultipleCompaniesAccounting");
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogCompanies", "Enabled", ConstantsSet.FunctionalOptionAccountingByMultipleCompanies);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleDepartments" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogStructuralUnitsDepartment", "Enabled", ConstantsSet.FunctionalOptionAccountingByMultipleDepartments);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleBusinessActivities" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogBusinessActivities", "Enabled", ConstantsSet.FunctionalOptionAccountingByMultipleBusinessActivities);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionPlanEnterpriseResourcesImporting" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogEnterpriseResources", "Enabled", ConstantsSet.FunctionalOptionPlanEnterpriseResourcesImporting);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure("Value", ConstantValue), ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleDepartments" Then
		
		ThisForm.ConstantsSet.FunctionalOptionAccountingByMultipleDepartments = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleBusinessActivities" Then
		
		ThisForm.ConstantsSet.FunctionalOptionAccountingByMultipleBusinessActivities = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionAccountingFixedAssets" Then
		
		ThisForm.ConstantsSet.FunctionalOptionAccountingFixedAssets = CurrentValue;
		
	EndIf;
	
EndProcedure // ReturnFormAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Check on the option disable possibility AccountingBySeveralBusinessActivities.
//
&AtServer
Function CancellationUncheckAccountingBySeveralBusinessActivities() 
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	OtherActivity = Catalogs.BusinessActivities.Other;
	SelectionOfBusinessActivity = Catalogs.BusinessActivities.Select();
	While SelectionOfBusinessActivity.Next() Do
		
		If SelectionOfBusinessActivity.Ref <> Catalogs.BusinessActivities.MainActivity
			AND SelectionOfBusinessActivity.Ref <> OtherActivity Then
			
			RefArray = New Array;
			RefArray.Add(SelectionOfBusinessActivity.Ref);
			RefsTable = FindByRef(RefArray);
			
			If RefsTable.Count() > 0 Then
				
				ErrorText = NStr("en='In base business activity are used different from the main! Disabling the option is prohibited!';ru='В базе используются направления деятельности, отличные от основного! Снятие опции запрещено!'");
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ErrorText;
	
EndFunction // CancelDisableAccountingBySeveralBusinessActivities()

// Check on the option disable possibility AccountingBySeveralDepartments.
//
&AtServer
Function CancellationUncheckAccountingBySeveralDepartments() 
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	StructuralUnits.Ref
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	StructuralUnits.StructuralUnitType = &StructuralUnitType
		|	AND StructuralUnits.Ref <> &MainDepartment"
	);
	
	Query.SetParameter("StructuralUnitType", Enums.StructuralUnitsTypes.Department);
	Query.SetParameter("MainDepartment", Catalogs.StructuralUnits.MainDepartment);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en='In base departments are used different from the main! Disabling the option is prohibited!';ru='В базе используются подразделения, отличные от основного! Снятие опции запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancelDisableAccountingBySeveralDepartments()

// Check on the option disable possibility FixedAssetsAccounting.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingFixedAssets()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	FixedAssets.Company
		|FROM
		|	AccumulationRegister.FixedAssets AS FixedAssets"
	);
	
	QueryResult = Query.Execute();
	Cancel = Not QueryResult.IsEmpty();
	
	If Not Cancel Then
	
		Query = New Query(
			"SELECT TOP 1
			|	FixedAssetsOutput.Company
			|FROM
			|	AccumulationRegister.FixedAssetsOutput AS FixedAssetsOutput"
		);
		
		QueryResult = Query.Execute();
		Cancel = Not QueryResult.IsEmpty(); 
		
	EndIf;
	
	If Cancel Then
		
		ErrorText = NStr("en='In base there are register records by fixed assets! The flag removal is prohibited!';ru='В базе присутствуют движения по внеоборотным активам! Снятие флага запрещено!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancelDisableFunctionalOptionAccountingFixedAssets()

// Initialization of checking the possibility to disable the CurrencyTransactionsAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are references on departments unequal main department then it is not allowed to delete flag FunctionalOptionAccountingByMultipleDepartments
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleDepartments" Then
		
		If Constants.FunctionalOptionAccountingByMultipleDepartments.Get() <> ConstantsSet.FunctionalOptionAccountingByMultipleDepartments
			AND (NOT ConstantsSet.FunctionalOptionAccountingByMultipleDepartments) Then
			
			ErrorText = CancellationUncheckAccountingBySeveralDepartments();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are references on company unequal main company then it is not allowed to delete flag AccountingBySeveralBusinessActivities
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingByMultipleBusinessActivities" Then
		
		If Constants.FunctionalOptionAccountingByMultipleBusinessActivities.Get() <> ConstantsSet.FunctionalOptionAccountingByMultipleBusinessActivities
			AND (NOT ConstantsSet.FunctionalOptionAccountingByMultipleBusinessActivities) Then
			
			ErrorText = CancellationUncheckAccountingBySeveralBusinessActivities();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
	
	EndIf;
	
	
	// If there are records by register "Property" or "Property selection" then it is not allowed to delete flag FunctionalOptionFixedAssetsAccounting	
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingFixedAssets" Then
		
		If Constants.FunctionalOptionAccountingFixedAssets.Get() <> ConstantsSet.FunctionalOptionAccountingFixedAssets 
			AND (NOT ConstantsSet.FunctionalOptionAccountingFixedAssets) Then 
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingFixedAssets();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction // CheckAbilityToChangeAttributeValue()

// Procedure updates the constant set write and calls interface update
//
// NameRecords - String. Record name of constant set.
//
&AtServer
Procedure UpdateRecordSetOfConstants(NameRecords)
	
	If NameRecords = "FunctionalOptionAccountingByMultipleCompanies" OR NameRecords = "" Then
		
		ConstantsSet[NameRecords] = GetFunctionalOption("MultipleCompaniesAccounting");
		SetEnabled("ConstantsSet.FunctionalOptionAccountingByMultipleCompanies");
		
	EndIf;
	
EndProcedure // UpdateRecordSetOfConstants()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure // UpdateSystemParameters()

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogCompanies(Command)
	
	OpenForm("Catalog.Companies.ListForm");
	
EndProcedure // CatalogCompanies()

// Procedure - command handler SettingAccountingByCompanies
//
&AtClient
Procedure SettingAccountingOnCounterpartysCompanies(Command)
	
	OpenForm("DataProcessor.AdministrationPanelSB.Form.SettingAccountingByCompanies");
	
EndProcedure // SettingAccountingByCompanies()

// Procedure - command handler CatalogStructuralUnitsDepartment.
//
&AtClient
Procedure CatalogStructuralUnitsDepartment(Command)
	
	FilterStructure = New Structure("StructuralUnitType", PredefinedValue("Enum.StructuralUnitsTypes.Department"));
	OpenForm("Catalog.StructuralUnits.ListForm", New Structure("Filter", FilterStructure));
	
EndProcedure // CatalogStructuralUnitsDepartment()

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogBusinessActivities(Command)
	
	OpenForm("Catalog.BusinessActivities.ListForm");
	
EndProcedure // CatalogBusinessActivities()

// Procedure - command handler CatalogEnterpriseResources.
//
&AtClient
Procedure CatalogEnterpriseResources(Command)
	
	OpenForm("Catalog.KeyResources.ListForm");
	
EndProcedure // CatalogEnterpriseResources()

// Procedure - command handler CatalogEventStates.
//
&AtClient
Procedure CatalogEventStates(Command)
	
	OpenForm("Catalog.EventStates.ListForm");
	
EndProcedure // CatalogEventStates()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure // OnOpen()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet"
		AND Source = "FunctionalOptionAccountingByMultipleCompanies" Then
		
		UpdateRecordSetOfConstants(Source);
		
	EndIf;
	
EndProcedure // NotificationProcessing()

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose()
	
	RefreshApplicationInterface();
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnChange field FunctionalOptionAccountingByMultipleDepartments.
//
&AtClient
Procedure FunctionalOptionAccountingByMultipleDepartmentsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingByMultipleDepartmentsOnChange()

// Procedure - event handler OnChange field FunctionalOptionAccountingByMultipleBusinessActivities.
//
&AtClient
Procedure FunctionalOptionAccountingByMultipleBusinessActivitiesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingByMultipleBusinessActivitiesOnChange()

// Procedure - event handler OnChange field FunctionalOptionPlanEnterpriseResourcesImport.
//
&AtClient
Procedure FunctionalOptionPlanEnterpriseResourcesImportingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionPlanEnterpriseResourcesImportingOnChange()

// Procedure - event handler OnChange field FunctionalOptionAccountingCashMethodIncomeAndExpenses.
&AtClient
Procedure FunctionalOptionAccountingCashMethodIncomeAndExpensesOfIncomesAndExpencesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingCashMethodIncomeAndExpensesOnChange()

// Procedure - event handler OnChange field ProductsAndServicesSKUInContent.
//
&AtClient
Procedure ProductsAndServicesSKUInContentOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // ProductsAndServicesSKUInContent()

// Procedure - event handler OnChange field FunctionalOptionUseBudgeting.
//
&AtClient
Procedure FunctionalOptionUseBudgetingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseBudgetingOnChange()

// Procedure - event handler OnChange field FunctionalOptionFixedAssetsAccounting.
//
&AtClient
Procedure FunctionalOptionAccountingFixedAssetsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingFixedAssetsOnChange()

&AtClient
Procedure FunctionalOptionUseVATOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure
