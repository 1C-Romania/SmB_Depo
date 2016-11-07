////////////////////////////////////////////////////////////////////////////////
// COMMON USE PROCEDURES

&AtClient
// Filters for the staff list tabular section are set to the procedure
//
Procedure SetFilter()
	
	
	SmallBusinessClientServer.SetListFilterItem(List,"Company",Company);

	If Not AccountingBySeveralDivisions Then
		
		SmallBusinessClientServer.SetListFilterItem(List,"StructuralUnit",MainDivision);
		
	ElsIf Items.Divisions.CurrentData <> Undefined Then
		
		SmallBusinessClientServer.SetListFilterItem(List,"StructuralUnit",Items.Divisions.CurrentData.Ref);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Constants.AccountingBySubsidiaryCompany.Get() Then
		
		Company = Constants.SubsidiaryCompany.Get();
		Items.Company.Visible = False;
		
	ElsIf Parameters.Filter.Property("Company") Then
		
		Company = Parameters.Filter.Company;
		Items.Company.Enabled = False;
		
	Else
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		
		If ValueIsFilled(SettingValue) Then
			
			Company = SettingValue;
			
		Else
			
			Company = Catalogs.Companies.MainCompany;
			
		EndIf;
		
	EndIf;
	
	AccountingBySeveralDivisions = Constants.FunctionalOptionAccountingByMultipleDivisions.Get();
	MainDivision = Catalogs.StructuralUnits.MainDivision;
	If Not AccountingBySeveralDivisions Then
		
		Items.Divisions.Visible = False;
		SmallBusinessClientServer.SetListFilterItem(List,"Company",Company);
		SmallBusinessClientServer.SetListFilterItem(List,"StructuralUnit",MainDivision);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

&AtClient
// Procedure - event handler OnChange attribute Company
//
Procedure CompanyOnChange(Item)
	
	SetFilter();
	
EndProcedure

&AtClient
// Procedure - OnActivateRow event processor of the Subdivisions table.
//
Procedure DivisionsOnActivateRow(Item)
	
	SetFilter();
	
EndProcedure
















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
