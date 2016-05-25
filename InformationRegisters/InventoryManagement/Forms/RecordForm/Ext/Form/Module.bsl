﻿////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	If Not ValueIsFilled(Record.SourceRecordKey.ProductsAndServices) Then
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Record.Company = SettingValue;
		Else
			Record.Company = Catalogs.Companies.MainCompany;		
		EndIf;
	EndIf;
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Record.Company = Constants.SubsidiaryCompany.Get();
		Items.Company.ReadOnly = True;
	EndIf; 
	
EndProcedure // OnCreateAtServer()



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
