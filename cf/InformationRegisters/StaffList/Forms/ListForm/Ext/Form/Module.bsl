////////////////////////////////////////////////////////////////////////////////
// COMMON USE PROCEDURES

&AtClient
// Filters for the staff list tabular section are set to the procedure
//
Procedure SetFilter()
	
	
	SmallBusinessClientServer.SetListFilterItem(List,"Company",Company);

	If Not AccountingBySeveralDepartments Then
		
		SmallBusinessClientServer.SetListFilterItem(List,"StructuralUnit",MainDepartment);
		
	ElsIf Items.Departments.CurrentData <> Undefined Then
		
		SmallBusinessClientServer.SetListFilterItem(List,"StructuralUnit",Items.Departments.CurrentData.Ref);
		
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
	
	AccountingBySeveralDepartments = Constants.FunctionalOptionAccountingByMultipleDepartments.Get();
	MainDepartment = Catalogs.StructuralUnits.MainDepartment;
	If Not AccountingBySeveralDepartments Then
		
		Items.Departments.Visible = False;
		SmallBusinessClientServer.SetListFilterItem(List,"Company",Company);
		SmallBusinessClientServer.SetListFilterItem(List,"StructuralUnit",MainDepartment);
		
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
// Procedure - OnActivateRow event processor of the Subdepartments table.
//
Procedure DepartmentsOnActivateRow(Item)
	
	SetFilter();
	
EndProcedure
