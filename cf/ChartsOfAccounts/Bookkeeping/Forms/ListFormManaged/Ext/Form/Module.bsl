&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Items.List.ChoiceMode = Parameters.ChoiceMode;
EndProcedure


&AtClient
Procedure OnOpen(Cancel)
	YearValidity = CommonAtServer.GetLastFinancialYear();
	YearValidityOnChange(Undefined);
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	YearValidityOnChangeAtServer();		
	Items.List.CurrentRow = SelectedValue;
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Clone Then
		Return;
	EndIf;
	
	Cancel = True;
	
	ParametersFormSettings = New Structure;
	
	// by Jack ParametersFormSettings.Insert("Account",Item.CurrentData.Ref);
	// by Jack 30.03.2017 add begin
	If Item.CurrentData<>Undefined Then 
	   ParametersFormSettings.Insert("Account",Item.CurrentData.Ref);
	EndIf;
	// by Jack 30.03.2017 add end

	
	NotifyDescription = New NotifyDescription("OnCloseParentChoice",ThisForm);	
	OpenForm("ChartOfAccounts.Bookkeeping.Form.NewAccountParentChoiceFormManaged",ParametersFormSettings,,,,,NotifyDescription);
	
EndProcedure

&AtClient
Procedure OnCloseParentChoice(Result, ParametersStructure) Export
	If TypeOf(Result) = Type("ChartOfAccountsRef.Bookkeeping")  Then
		OpenForm("ChartOfAccounts.Bookkeeping.ObjectForm", New Structure("Parent,ChoiceMode", Result,True),ThisForm);			
	EndIf;	
EndProcedure	

&AtClient
Procedure YearValidityOnChange(Item)
	YearValidityOnChangeAtServer();
EndProcedure

&AtServer
Procedure YearValidityOnChangeAtServer()
	FilterRef = Undefined;
	For Counter = 0 To List.Filter.Items.Count()-1 Do
		CurrentFilter = List.Filter.Items[Counter];
		If CurrentFilter.LeftValue = List.Filter.FilterAvailableFields.Items.Find("Ref").Field Then
			FilterRef = CurrentFilter;
		EndIf; 
	EndDo;  
	If FilterRef=Undefined Then
		FilterRef = List.Filter.Items.Add(Type("DataCompositionFilterItem"));	
	EndIf;

	If ValueIsFilled(YearValidity) Then
		Query = New Query;
		Query.Text = "SELECT
		             |	Bookkeeping.Ref
		             |FROM
		             |	ChartOfAccounts.Bookkeeping AS Bookkeeping
		             |WHERE
		             |	CASE
		             |			WHEN Bookkeeping.FinancialYearsBegin = VALUE(Catalog.FinancialYears.EmptyRef)
		             |				THEN TRUE
		             |			ELSE Bookkeeping.FinancialYearsBegin.DateFrom <= &DateEndYearValidity
		             |		END
		             |	AND CASE
		             |			WHEN Bookkeeping.FinancialYearsEnd = VALUE(Catalog.FinancialYears.EmptyRef)
		             |				THEN TRUE
		             |			ELSE Bookkeeping.FinancialYearsEnd.DateTo >= &DateStartYearValidity
		             |		END";
		
		Query.SetParameter("DateStartYearValidity", YearValidity.DateFrom);
		Query.SetParameter("DateEndYearValidity", YearValidity.DateTo);
		
		ValueForFilter = New ValueList;
		ValueForFilter.LoadValues(Query.Execute().Unload().UnloadColumn("Ref"));
	
		FilterRef.ComparisonType = DataCompositionComparisonType.InList;
		FilterRef.LeftValue = List.Filter.FilterAvailableFields.Items.Find("Ref").Field;
		FilterRef.RightValue = ValueForFilter;
		FilterRef.Use = True;		
	Else
		FilterRef.ComparisonType = DataCompositionComparisonType.InList;
		FilterRef.LeftValue = List.Filter.FilterAvailableFields.Items.Find("Ref").Field;
		FilterRef.RightValue = Undefined;		
		FilterRef.Use = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure CommandPrintOut(Command)
	OpenForm("ChartOfAccounts.Bookkeeping.Form.PrintOutFormManaged",New Structure("YearValidity", YearValidity)  , ThisForm);
EndProcedure





