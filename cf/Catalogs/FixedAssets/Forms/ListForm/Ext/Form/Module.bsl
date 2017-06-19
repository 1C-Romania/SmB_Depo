////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets availability of the form items.
//
&AtClient
Procedure SetEnabled()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		If Not CurrentData.Property("RowGroup")
			  AND ValueIsFilled(CurrentData.State)
			  AND CurrentData.State = FixedAssetsStatesStructure.AcceptedForAccounting Then
			
			Items.ListChangeParameters.Enabled = True;
			Items.ListWriteOff.Enabled = True;
			Items.ListSell.Enabled = True;
			If CurrentData.DepreciationMethod = StructureMethodsOfDepreciationCalculation.ProportionallyToProductsVolume Then
				Items.ListEnterDepreciation.Enabled = True;
			Else
				Items.ListEnterDepreciation.Enabled = False;
			EndIf;
			Items.ListAcceptForAccounting.Enabled = False;
			
		ElsIf Not CurrentData.Property("RowGroup")
			  AND ValueIsFilled(CurrentData.State)
			  AND CurrentData.State = FixedAssetsStatesStructure.RemoveFromAccounting Then
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = False;
			
		ElsIf Not CurrentData.Property("RowGroup")
			  AND ValueIsFilled(CurrentData.State)
			  AND CurrentData.State = "Not accepted for accounting" Then
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = True;
			
		Else
			
			Items.ListChangeParameters.Enabled = False;
			Items.ListWriteOff.Enabled = False;
			Items.ListSell.Enabled = False;
			Items.ListEnterDepreciation.Enabled = False;
			Items.ListAcceptForAccounting.Enabled = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetEnabled()

// Function receives the period of the last depreciation calculation.
//
&AtServerNoContext
Function GetPeriodOfLastDepreciation(Val Company)
	
	Query = New Query(
	"SELECT TOP 1
	|	FixedAssets.Period AS Date
	|FROM
	|	AccumulationRegister.FixedAssets AS FixedAssets
	|WHERE
	|	FixedAssets.Company = &Company
	|	AND VALUETYPE(FixedAssets.Recorder) = Type(Document.FixedAssetsDepreciation)
	|
	|ORDER BY
	|	FixedAssets.Period DESC");
	
	Company = ?(GetFunctionalOption("UseSeveralCompanies"), Company, Catalogs.Companies.MainCompany);
	
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(Company));
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return NStr("en='Last accrual: ';ru='Последнее начисление: '") + Format(Selection.Date, "DLF=DD");
	Else
		Return "";
	EndIf;
	
EndFunction // GetPeriodOfLastDepreciation()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FixedAssetsStatesStructure = New Structure;
	FixedAssetsStatesStructure.Insert("AcceptedForAccounting", Enums.FixedAssetsStates.AcceptedForAccounting);
	FixedAssetsStatesStructure.Insert("RemoveFromAccounting", Enums.FixedAssetsStates.RemoveFromAccounting);
	
	StructureMethodsOfDepreciationCalculation = New Structure;
	StructureMethodsOfDepreciationCalculation.Insert("Linear", Enums.FixedAssetsDepreciationMethods.Linear);
	StructureMethodsOfDepreciationCalculation.Insert("ProportionallyToProductsVolume", Enums.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume);
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

// Procedure - OnLoadDataFromSettingsAtServer form event handler.
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	State = Settings.Get("State");
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	SmallBusinessClientServer.SetListFilterItem(List, "State", State, ValueIsFilled(State));
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
EndProcedure // OnLoadDataFromSettingsAtServer()

// Procedure - OnLoadDataFromSettingsAtServer form event handler.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "TextUpdatePeriodOfLastDepreciationCalculation" Then
		PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	ElsIf EventName = "FixedAssetsStatesUpdate" Then
		SetEnabled();
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - handler of clicking AcceptForAccounting button.
//
&AtClient
Procedure AcceptForAccounting(Command)
	
	ListOfParameters = New Structure("Basis", Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetsEnter.ObjectForm", ListOfParameters);
	
EndProcedure // AcceptForAccounting()

// Procedure - handler of clicking ChangeParameters button.
//
&AtClient
Procedure ChangeParameters(Command)
	
	ListOfParameters = New Structure("Basis", Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetsModernization.ObjectForm", ListOfParameters);
	
EndProcedure // ChangeParameters()

// Procedure - handler of clicking ChargeDepreciation button.
//
&AtClient
Procedure ChargeDepreciation(Command)
	
	ListOfParameters = New Structure("Basis", Company);
	
	OpenForm("Document.FixedAssetsDepreciation.ObjectForm", ListOfParameters);
	
EndProcedure // AccrueDepreciation()

// Procedure - handler of clicking Sell button.
//
&AtClient
Procedure Sell(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetsTransfer.ObjectForm", ListOfParameters);
	
EndProcedure // Sell()

// Procedure - handler of clicking WriteOff button.
//
&AtClient
Procedure WriteOff(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetsWriteOff.ObjectForm", ListOfParameters);
	
EndProcedure // WriteOff()

// Procedure - handler of clicking EnterWorkOutput button.
//
&AtClient
Procedure EnterWorkOutput(Command)
	
	ListOfParameters = New Structure("Basis",  Items.List.CurrentRow);
	
	OpenForm("Document.FixedAssetsOutput.ObjectForm", ListOfParameters);
	
EndProcedure // EnterWorkOutput()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnChange of the Company input field.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
	PeriodOfLastDepreciation = GetPeriodOfLastDepreciation(Company);
	
EndProcedure // CompanyOnChange()

// Procedure - event handler OnChange of the State input field.
//
&AtClient
Procedure StatusOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "State", State, ValueIsFilled(State));
	
EndProcedure // StatusOnChange()

// Procedure - event handler OnActivateRow of the List tabular section.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	SetEnabled();
	
EndProcedure // ListOnActivateRow()
