Function DeleteDocumentsRowsWithSuperfluousPartners(SettlementDocuments,Val RowsToDeleteArray) Export
		
	If RowsToDeleteArray.Count() > 0 Then
		
		PartnersToDeleteList = New ValueList;
		PartnersToDeleteListStr = "";
		For Each RowToDelete In RowsToDeleteArray Do
			SettlementDocumentsRow = SettlementDocuments.FindByID(RowToDelete);
			If PartnersToDeleteList.FindByValue(SettlementDocumentsRow.Partner) = Undefined Then
				PartnersToDeleteList.Add(SettlementDocumentsRow.Partner);
				PartnersToDeleteListStr = PartnersToDeleteListStr + Chars.LF + "- " + SettlementDocumentsRow.Partner;
			EndIf;
		EndDo;
		
		QueryText = NStr("en = 'The rows with the partners below would be deleted from the document:%PartnersList
						 |Do you want to continue?'; pl = 'Wierszy zawierające kontahentów z listy poniżej zostaną wykasowane:%PartnersList
						 |Czy chcesz wykonać zmiany?'");
		
		QueryText = StrReplace(QueryText, "%PartnersList", PartnersToDeleteListStr);
		Answer = DoQueryBox(QueryText, QuestionDialogMode.YesNo);
		
		If Answer = DialogReturnCode.Yes Then
			
			For Each RowToDelete In RowsToDeleteArray Do	
				SettlementDocuments.Delete(SettlementDocuments.IndexOf(SettlementDocuments.FindByID(RowToDelete)));
			EndDo;
			
			Return True;
			
		Else
			Return False;
		EndIf;
		
	Else
		Return True;
	EndIf;
	
EndFunction

Procedure PartnersDocumentStartChoice(Val Document, Val Partner, Val Currency, Val Control) Export
	
	ReturnStructure = APARAtServer.PartnersDocumentStartChoiceAtServer(Document, Partner, Currency);
	If ReturnStructure<>Undefined Then
		OpenForm(ReturnStructure.FormName,ReturnStructure.ParametersStructure,Control,Control);
	EndIf;	
	
EndProcedure

Function GetFullEmployeesList(OtherEmployeesList, Employee = Undefined, PrepaymentSettlement = Undefined) Export
	
	If PrepaymentSettlement = PredefinedValue("Enum.PrepaymentSettlement.Prepayment") Then
		
		ValueListArray = New Array;
		ValueListArray.Add(Employee);
		Return ValueListArray;
		
	Else
		
		ValueListArray = OtherEmployeesList.UnloadValues();
		If Employee <> Undefined Then
			ValueListArray.Insert(0, Employee);
		EndIf;
		
		Return ValueListArray;
	EndIf;	
	
EndFunction

Function GetPrepaymentSettlementList() Export
		
	ValueListArray = New Array;
	ValueListArray.Add(PredefinedValue("Enum.PrepaymentSettlement.Settlement"));
	ValueListArray.Add(PredefinedValue("Enum.PrepaymentSettlement.PrepaymentSettlement"));
	
	Return ValueListArray;
	
EndFunction

Procedure AmountOnChange(CurrentRow, ColumnName, MultiCurrencySettlement = False, ExchangeRates = Undefined, LockSettlementAmountToAmountCalculation = False) Export
	
	CurrencyStructure = APARAtServer.GetDocumentsCurrencyAndExchangeRate(CurrentRow.Document);
	
	If MultiCurrencySettlement Then
		
		FoundRows = ExchangeRates.FindRows(New Structure("Currency", CurrentRow.DocumentSettlementCurrency));
		CrossRate = FoundRows[0].CrossExchangeRate;
		
	EndIf;
	
	If ColumnName = "AmountDr" And CurrentRow.AmountDr <> 0 Then
		
		CurrentRow.AmountDrNational = CommonAtServer.GetNationalAmount(CurrentRow.AmountDr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
		CurrentRow.AmountCr = 0;
		CurrentRow.AmountCrNational = 0;
		If MultiCurrencySettlement AND NOT LockSettlementAmountToAmountCalculation Then
			CurrentRow.AmountCrSettlement = 0;
			CurrentRow.AmountDrSettlement = CurrentRow.AmountDr * CrossRate;
		EndIf;	
		
	ElsIf ColumnName = "AmountDrNational" And CurrentRow.AmountDrNational <> 0 Then
		
		CurrentRow.AmountCr = 0;
		CurrentRow.AmountCrNational = 0;
		If MultiCurrencySettlement Then
			CurrentRow.AmountCrSettlement = 0;
		EndIf;	
		
	ElsIf MultiCurrencySettlement AND ColumnName = "AmountDrSettlement" And CurrentRow.AmountDrSettlement <> 0 Then
		
		CurrentRow.AmountCr = 0;
		CurrentRow.AmountCrNational = 0;
		CurrentRow.AmountCrSettlement = 0;
		
		CurrentRow.AmountDr = CurrentRow.AmountDrSettlement / CrossRate;
		CurrentRow.AmountDrNational = CommonAtServer.GetNationalAmount(CurrentRow.AmountDr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
		
	ElsIf ColumnName = "AmountCr" And CurrentRow.AmountCr <> 0 Then
		
		CurrentRow.AmountCrNational = CommonAtServer.GetNationalAmount(CurrentRow.AmountCr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
		CurrentRow.AmountDr = 0;
		CurrentRow.AmountDrNational = 0;
		If MultiCurrencySettlement AND NOT LockSettlementAmountToAmountCalculation Then
			CurrentRow.AmountDrSettlement = 0;
			CurrentRow.AmountCrSettlement = CurrentRow.AmountCr * CrossRate;
		EndIf;	
		
	ElsIf ColumnName = "AmountCrNational" And CurrentRow.AmountCrNational <> 0 Then
		
		CurrentRow.AmountDr = 0;
		CurrentRow.AmountDrNational = 0;
		If MultiCurrencySettlement Then
			CurrentRow.AmountDrSettlement = 0;
		EndIf;	
		
	ElsIf MultiCurrencySettlement AND ColumnName = "AmountCrSettlement" And CurrentRow.AmountCrSettlement <> 0 Then
		
		CurrentRow.AmountDr = 0;
		CurrentRow.AmountDrNational = 0;
		CurrentRow.AmountDrSettlement = 0;
		
		CurrentRow.AmountCr = CurrentRow.AmountCrSettlement / CrossRate;
		CurrentRow.AmountCrNational = CommonAtServer.GetNationalAmount(CurrentRow.AmountCr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
		
	EndIf;
	
EndProcedure

Function ChooseEmployee(TakeIntoAccountOtherEmployees, OtherEmployeesList, Employee) Export
	
	If TakeIntoAccountOtherEmployees Then
		
		ValueList = APARAtServer.GetFullEmployeesList(OtherEmployeesList, Employee);
		ValueListItem = ValueList.ChooseItem();
		If ValueListItem = Undefined Then
			Return Undefined;
		Else
			Return ValueListItem.Value;
		EndIf;
		
	Else
		Return Employee;
	EndIf;
	
EndFunction