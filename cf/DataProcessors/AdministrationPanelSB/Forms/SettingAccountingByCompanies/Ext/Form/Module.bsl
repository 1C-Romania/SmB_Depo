
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure updates the availability of the Company flag RunAccountingBySubsidiaryCompany.
//
&AtClient
Procedure RefreshSubsidiaryCompanyEnabled()
	
	Items.SubsidiaryCompany.Enabled = ConstantsSet.AccountingBySubsidiaryCompany;
	Items.SubsidiaryCompany.AutoChoiceIncomplete = ConstantsSet.AccountingBySubsidiaryCompany;
	Items.SubsidiaryCompany.AutoMarkIncomplete = ConstantsSet.AccountingBySubsidiaryCompany;
	
	If Not ConstantsSet.AccountingBySubsidiaryCompany Then
		ConstantsSet.SubsidiaryCompany = PredefinedValue("Catalog.Companies.EmptyRef");
	EndIf;
	
EndProcedure // RefreshSubsidiaryCompanyEnabled()

// Check on the possibility to disable the MultipleCompaniesAccounting option.
//
&AtServer
Function CancellationUncheckAccountingByMultipleCompaniesAccounting()
	
	SetPrivilegedMode(True);
	
	Cancel = False;
	
	MainCompany = Catalogs.Companies.MainCompany;
	
	SelectionCompanies = Catalogs.Companies.Select();
	While SelectionCompanies.Next() Do
		
		If SelectionCompanies.Ref <> MainCompany Then
			
			RefArray = New Array;
			RefArray.Add(SelectionCompanies.Ref);
			RefsTable = FindByRef(RefArray);
			
			If RefsTable.Count() > 0 Then
				
				MessageText = NStr("en='Companies that differ from the main one are used in the base! Disabling the option is prohibited!';ru='В базе используются организации, отличные от основной! Снятие опции запрещено!'");
				SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText, , , "ConstantsSet.FunctionalOptionAccountingByMultipleCompanies", Cancel);
				Break;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return Cancel;
	
EndFunction // CancellationUncheckAccountingByMultipleCompaniesAccounting()

// Check on the possibility to change the established company.
//
&AtServer
Function CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany(FieldName)
	
	SubsidiaryCompany = ConstantsSet.SubsidiaryCompany;
	AccumulationRegistersCounter = 0;
	Query = New Query;
	Query.SetParameter("SubsidiaryCompany", SubsidiaryCompany);
	
	For Each AccumulationRegister IN Metadata.AccumulationRegisters Do
		
		If AccumulationRegister = AccumulationRegisters.JobSheets Then
			Continue;
		EndIf;
			
		Query.Text = Query.Text + 
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1", 
				"UNION ALL 
				|
				|SELECT TOP 1 ") + "
				|
				|	AccumulationRegister" + AccumulationRegister.Name + ".Company
				|FROM
				|	AccumulationRegister." + AccumulationRegister.Name + " AS " + "AccumulationRegister" + AccumulationRegister.Name + "
				|WHERE
				|	AccumulationRegister" + AccumulationRegister.Name + ".Company <> &SubsidiaryCompany
				|";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
		
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
		
		EndTry;
	EndIf;
	
	If AreRecords Then
		MessageText = NStr("en='There are records of an organization other than the company in the base! Parameter change is prohibited!';ru='В базе есть движения от организации, отличной от компании! Изменение параметра запрещено!'");
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText, , , FieldName);
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction // CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany()

// Check on the possibility to disable the AccountingBySubsidiaryCompany option.
//
&AtServer
Function CancellationUncheckAccountingBySubsidiaryCompany()
	
	SubsidiaryCompany = Constants.SubsidiaryCompany.Get();
	DocumentsCounter = 0;
	Query = New Query;
	For Each Doc IN Metadata.Documents Do
		
		If Doc.Posting = Metadata.ObjectProperties.Posting.Deny Then
			Continue;
		EndIf;

		Query.Text = Query.Text +
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1",
				"UNION ALL
				|
				|SELECT TOP 1 ") + "
				|
				|	Document" + Doc.Name + ".Ref FROM Document." + Doc.Name + " AS " + "Document" + Doc.Name + "
				|	WHERE document" + Doc.Name + ".Company
				|	<> &SubsidiaryCompany AND Document" + Doc.Name + ".Posted
				|";
		
		DocumentsCounter = DocumentsCounter + 1;
		
		If DocumentsCounter > 3 Then
			DocumentsCounter = 0;
			Try
				Query.SetParameter("SubsidiaryCompany", SubsidiaryCompany);
				QueryResult = Query.Execute();
				AreDocuments = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreDocuments Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
		
	EndDo;
	
	If DocumentsCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			AreDocuments = Not QueryResult.IsEmpty();
		Except
			
		EndTry;
	EndIf;
	
	If AreDocuments Then
		MessageText = NStr("en='In the base there are posted documents from an organization other than company! You can not clear the ""Accounting by company"" check box!';ru='В базе есть проведенные документы от организации, отличной от компании! Снятие флага ""Учет по компании"" запрещено!'");	
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText, , , "ConstantsSet.AccountingBySubsidiaryCompany");
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction // CancellationUncheckAccountingBySubsidiaryCompany()()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogCompanies(Command)
	
	If Modified Then
		
		Message = New UserMessage();
		Message.Text = NStr("en='Data is not written yet! You can start editing the ""Companies"" catalog only after the data is written!';ru='Данные еще не записаны! Переход к редактированию справочника ""Организации"" возможен только после записи данных!'");
		Message.Message();
		Return;
		
	EndIf;
	
	If ConstantsSet.FunctionalOptionAccountingByMultipleCompanies Then
		
		OpenForm("Catalog.Companies.ListForm");
		
	Else
		
		ParemeterCompany = New Structure("Key", PredefinedValue("Catalog.Companies.MainCompany"));
		OpenForm("Catalog.Companies.ObjectForm", ParemeterCompany);
		
	EndIf;
	
EndProcedure // CatalogCompanies()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	RefreshSubsidiaryCompanyEnabled();
	ConstantValue = ConstantsSet.FunctionalOptionAccountingByMultipleCompanies;
	
	Items.CompanySettingsSettings.Enabled	= ConstantValue;
	ValueOnOpenAccountingForSeveralCompanies 	= ConstantValue;
	
EndProcedure // OnOpen()

// Procedure - event handler BeforeWriteAtServer form.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// If there are references to the company different from the main company, it is not allowed to clear the MultipleCompaniesAccounting flag.
	If Constants.FunctionalOptionAccountingByMultipleCompanies.Get() <> ConstantsSet.FunctionalOptionAccountingByMultipleCompanies
		AND (NOT ConstantsSet.FunctionalOptionAccountingByMultipleCompanies) 
		AND CancellationUncheckAccountingByMultipleCompaniesAccounting() Then
		
		ConstantsSet.FunctionalOptionAccountingByMultipleCompanies = True;
		Cancel = True;
		Return;
		
	EndIf;
	
	// If the AccountingBySubsidiaryCompany flag is set, then the company must be filled.
	If ConstantsSet.AccountingBySubsidiaryCompany 
		AND Not ValueIsFilled(ConstantsSet.SubsidiaryCompany) Then
		
		MessageText = NStr("en='The ""Account by company"" check box is selected, but the ""Organization-company"" is not filled!';ru='Установлен флаг ""Вести учет по компании"", но не заполнена ""Организация-компания""!'");
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText, , , "ConstantsSet.SubsidiaryCompany", Cancel);
		Return;
		
	EndIf;
	
	// If there are any records of the company different from the selected company, it is not allowed to select AccountingBySubsidiaryCompany.
	If Constants.AccountingBySubsidiaryCompany.Get() <> ConstantsSet.AccountingBySubsidiaryCompany AND ConstantsSet.AccountingBySubsidiaryCompany
		AND CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany("ConstantsSet.AccountingBySubsidiaryCompany") Then
		
		ConstantsSet.AccountingBySubsidiaryCompany = False;
		ConstantsSet.SubsidiaryCompany = Catalogs.Companies.EmptyRef();
		Items.SubsidiaryCompany.Enabled = False;
		Items.SubsidiaryCompany.AutoChoiceIncomplete = False;
		Items.SubsidiaryCompany.AutoMarkIncomplete = False;
		Cancel = True;
		Return;
		
	EndIf;
	
	// If there are any posted documents of the company different from the company, it is not allowed to clear AccountingBySubsidiaryCompany.
	If Constants.AccountingBySubsidiaryCompany.Get() <> ConstantsSet.AccountingBySubsidiaryCompany AND (NOT ConstantsSet.AccountingBySubsidiaryCompany)
		AND CancellationUncheckAccountingBySubsidiaryCompany() Then
		
		ConstantsSet.AccountingBySubsidiaryCompany = True;
		ConstantsSet.SubsidiaryCompany = Constants.SubsidiaryCompany.Get();
		Items.SubsidiaryCompany.Enabled = True;
		Items.SubsidiaryCompany.AutoChoiceIncomplete = True;
		Items.SubsidiaryCompany.AutoMarkIncomplete = True;
		Cancel = True;
		Return;
		
	EndIf;
	
	// If there are any records of the company different from the selected company, it is not allowed to change Company.
	If Constants.SubsidiaryCompany.Get() <> ConstantsSet.SubsidiaryCompany
		AND ValueIsFilled(ConstantsSet.SubsidiaryCompany)
		AND ValueIsFilled(Constants.SubsidiaryCompany.Get())
		AND CancellationSetAccountingBySubsidiaryCompanyChangeSubsidiaryCompany("ConstantsSet.SubsidiaryCompany") Then
		
		ConstantsSet.SubsidiaryCompany = Constants.SubsidiaryCompany.Get();
		Cancel = True;
		Return;
		
	EndIf;
	
EndProcedure // BeforeWriteAtServer()

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	ConstantValue = ConstantsSet.FunctionalOptionAccountingByMultipleCompanies;
	If ValueOnOpenAccountingForSeveralCompanies <> ConstantValue Then
		
		Notify("Record_ConstantsSet", New Structure("Value", ConstantValue), "FunctionalOptionAccountingByMultipleCompanies");
		
	EndIf;
	
EndProcedure // AfterWrite()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnChange of the AccountingBySubsidiaryCompany field.
//
&AtClient
Procedure AccountingBySubsidiaryCompanyOnChange(Item)
	
	If ConstantsSet.AccountingBySubsidiaryCompany
	AND Not ValueIsFilled(ConstantsSet.SubsidiaryCompany) Then
		ConstantsSet.SubsidiaryCompany = PredefinedValue("Catalog.Companies.MainCompany");
	EndIf;
	
	RefreshSubsidiaryCompanyEnabled();
	
EndProcedure // AccountingBySubsidiaryCompanyOnChange()

// Procedure - event handler OnChange of the FunctionalOptionAccountingByMultipleCompanies field.
//
&AtClient
Procedure FunctionalOptionAccountingByMultipleCompaniesOnChange(Item)
	
	ConstantValue = ConstantsSet.FunctionalOptionAccountingByMultipleCompanies;
	
	If Not ConstantValue Then
		
		ConstantsSet.AccountingBySubsidiaryCompany = False;
		ConstantsSet.SubsidiaryCompany = "";
		
	EndIf;
	
	RefreshSubsidiaryCompanyEnabled();
	Items.CompanySettingsSettings.Enabled = ConstantValue;
	
EndProcedure // FunctionalOptionAccountingByMultipleCompaniesOnChange()
// 














