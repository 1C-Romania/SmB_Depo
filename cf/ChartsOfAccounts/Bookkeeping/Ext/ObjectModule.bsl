
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENTS PROCESSING OF THE OBJECT

Procedure BeforeWrite(Cancel)
	
	If BalanceSide = Enums.AccountBalanceSides.DrCr Then
		Type = AccountType.ActivePassive;
	ElsIf BalanceSide = Enums.AccountBalanceSides.Dr Then
		Type = AccountType.Active;
	ElsIf BalanceSide = Enums.AccountBalanceSides.Cr Then
		Type = AccountType.Passive;
	Else
		Type = Undefined;
	EndIf;
	
	Quantity = False;
	CodeForInput = StrReplace(Code, "-", "");
	
	Resultant  = (BalanceType = Enums.AccountBalanceTypes.Result);
	OffBalance = (BalanceType = Enums.AccountBalanceTypes.OffBalance);
	
	// Adjust ext dimensions
	AdjustExtDimensions(ExtDimension1Type, ExtDimension1Mandatory, 0, Cancel);
	AdjustExtDimensions(ExtDimension2Type, ExtDimension2Mandatory, 1, Cancel);
	AdjustExtDimensions(ExtDimension3Type, ExtDimension3Mandatory, 2, Cancel);
	
	If Not DataExchange.Load Then
		
		// Call checking.
		AllAttributesValueTable = Alerts.AlertsExpandAttributesValueTable(Alerts.AlertReturnPredefinedAttributesValueTableByObject(ThisObject),GetAttributesValueTableForValidation());
		
		Alerts.AlertDoCommonCheck(ThisObject,AllAttributesValueTable,,Cancel);
		
		If Cancel Then
			Return;
		EndIf;
		
		// Account checks
		// Forbid to add subaccounts for account that is used in register.
		// Forbid to change attributes for account that is used in register.
		// If Paren is filled this attributes should be the same: BalanceType, Purpose.
		// Ext dimensions of subaccount should be the same as parent account has. We can only add if it's possible.
		// Description should be unique.
		// On change ext dimensions types adjust nested accounts ext dimensions.
		
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OTHER PROCEDURES AND FUNCTIONS

Function GetAccountMask() Export
	
	If Parent.IsEmpty() Then
		Mask = "";
	Else
		Mask = Parent.Code + "-";
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	             |	Bookkeeping.Code
	             |FROM
	             |	ChartOfAccounts.Bookkeeping AS Bookkeeping
	             |WHERE
	             |	Bookkeeping.Parent = &Parent
	             |	AND Bookkeeping.Ref <> &Ref";
	
	Query.SetParameter("Parent", Parent);
	Query.SetParameter("Ref", Ref);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then // we have another subaccounts on the same level
		BrotherFullCode = TrimAll(Selection.Code);
		BrotherCode = Mid(BrotherFullCode, StrLen(Mask) + 1);
		BrotherCodeLen = StrLen(BrotherCode);
	Else
		BrotherCodeLen = Metadata.ChartsOfAccounts.Bookkeeping.CodeLength - StrLen(Mask);
	EndIf;
	
	For i = 1 To BrotherCodeLen Do
		Mask = Mask + "@";
	EndDo;
	If ValueIsFilled(FinancialYearsEnd) Then
		Mask = ?(NotValid,"*","") + Mask + ?(ValueIsFilled(FinancialYearsEnd.DateTo), Format(FinancialYearsEnd.DateTo,"DF=' (yyyy)'"),"");
	EndIf;
	Mask = StrReplace(Mask,"9","\9");
	Return Mask;
	
EndFunction

Procedure SetAttributesFromParent() Export
	
	BalanceType = Parent.BalanceType;
	BalanceSide = Parent.BalanceSide;
	Purpose = Parent.Purpose;
	Currency = Parent.Currency;
	
	ExtDimensionTypes.Clear();
	For Each ParentExtDimensionType In Parent.ExtDimensionTypes Do
		ExtDimensionType = ExtDimensionTypes.Add();
		FillPropertyValues(ExtDimensionType, ParentExtDimensionType, , "LineNumber, Predefined");
	EndDo;
	
EndProcedure

Procedure SetAttributesByPurpose() Export
	
	ExtDimensionTypes.Clear();
	
	If Purpose = Enums.AccountPurpose.AccountsPayable
		OR Purpose = Enums.AccountPurpose.AccountsPayablePrepayment Then
		
		Currency = True;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.Suppliers, 
			ChartsOfCharacteristicTypes.BookkeepingExtDimensions.PurchaseInvoices);
		
		ElsIf Purpose = Enums.AccountPurpose.AccountsReceivable
			OR Purpose = Enums.AccountPurpose.AccountsReceivablePrepayment Then
		
		Currency = True;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.Customers,
			ChartsOfCharacteristicTypes.BookkeepingExtDimensions.SalesInvoices);
		
	ElsIf Purpose = Enums.AccountPurpose.Bank Then
		
		Currency = True;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.BankAccounts);
		
	ElsIf Purpose = Enums.AccountPurpose.Cash Then
		
		Currency = True;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.CashDesks);
		
	ElsIf Purpose = Enums.AccountPurpose.Costs Then
		
		Currency = False;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.CostArticles,
			ChartsOfCharacteristicTypes.BookkeepingExtDimensions.Departments,
			ChartsOfCharacteristicTypes.BookkeepingExtDimensions.KUP_NKUP);
		
	ElsIf Purpose = Enums.AccountPurpose.Employees
			OR Purpose = Enums.AccountPurpose.EmployeesPrepayment Then
		
		Currency = False;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.Employees,
			ChartsOfCharacteristicTypes.BookkeepingExtDimensions.AccountsWithEmployee);
		
	ElsIf Purpose = Enums.AccountPurpose.FixedAssets Then
		
		Currency = False;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.FixedAssetsBalanceGroups,
			ChartsOfCharacteristicTypes.BookkeepingExtDimensions.FixedAssets);
		
	ElsIf Purpose = Enums.AccountPurpose.IntangibleAssents Then
		
		Currency = False;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.FixedAssetsBalanceGroups,
			ChartsOfCharacteristicTypes.BookkeepingExtDimensions.IntangibleAssets);
		
	ElsIf Purpose = Enums.AccountPurpose.GoodsAndServices Then
		
		Currency = False;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.ItemsAccountingGroups);
		
	ElsIf Purpose = Enums.AccountPurpose.VAT Then
		
		Currency = False;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.VATRates);
		
	ElsIf Purpose = Enums.AccountPurpose.PrepaidExpenses Then
		
		Currency = False;
		SetExtDimensions(ChartsOfCharacteristicTypes.BookkeepingExtDimensions.PrepaidExpensesCatalog);
		
	ElsIf Purpose = Enums.AccountPurpose.Other Then
		
		Currency = False;
		SetExtDimensions();
		
	EndIf;
	
EndProcedure

Procedure SetExtDimensions(NewExtDimension1Type = Undefined, NewExtDimension2Type = Undefined, NewExtDimension3Type = Undefined)
	
	If NewExtDimension1Type = Undefined Then
		ExtDimension1Type = Undefined;
		ExtDimension1Mandatory = False;
	Else
		ExtDimension1Type = NewExtDimension1Type;
		ExtDimension1Mandatory = True;
	EndIf;
	
	If NewExtDimension2Type = Undefined Then
		ExtDimension2Type = Undefined;
		ExtDimension2Mandatory = False;
	Else
		ExtDimension2Type = NewExtDimension2Type;
		ExtDimension2Mandatory = True;
	EndIf;
	
	If NewExtDimension3Type = Undefined Then
		ExtDimension3Type = Undefined;
		ExtDimension3Mandatory = False;
	Else
		ExtDimension3Type = NewExtDimension3Type;
		ExtDimension3Mandatory = True;
	EndIf;
	
EndProcedure

Function GetAttributesValueTableForValidation() Export
	
	AttributesStructure = New Structure("BalanceType, BalanceSide, Purpose");
	
	Return Alerts.AlertCreateAttributesValueTableFromStructure(AttributesStructure, Enums.AlertType.Error);
	
EndFunction

Function ElementChecks(Cancel = Undefined) Export
	
	AccountChecks(Cancel);
	ExtDimensionTypesChecks(Cancel);
	
EndFunction

Function AccountChecks(Cancel = Undefined) Export 
	
	// PARENT CHECKS
	If Not Parent.IsEmpty() Then
		
		If Alerts.IsNotEqualValue(BalanceType, Parent.BalanceType) Then
			Alerts.AddAlert(NStr("en = 'Balance type is differs from parent''s value:'; pl = 'Typ bilansowy różni się od wartości kona-rodzica:'") + " " + Parent.BalanceType, Enums.AlertType.Error, Cancel,ThisObject);
		EndIf;
		
		If Left(Code, StrLen(Parent.Code)) <> Parent.Code And NotValid = False Then
			Alerts.AddAlert(NStr("en = 'Code of the account should starts from:'; pl = 'Kod konta powinien się zaczynać od:'") + " " + Parent.Code, Enums.AlertType.Error, Cancel,ThisObject);
		EndIf;
		
		If Alerts.IsNotEqualValue(Purpose, Parent.Purpose) Then
			Alerts.AddAlert(NStr("en = 'Purpose is differs from parent''s value:'; pl = 'Przeznaczenie różni się od wartości kona-rodzica:'") + " " + Parent.Purpose, Enums.AlertType.Error, Cancel,ThisObject);
		EndIf;
		
		If Alerts.IsNotEqualValue(Currency, Parent.Currency) Then
			Alerts.AddAlert(NStr("en = 'Currency flag is differs from parent''s value:'; pl = 'Cecha walitowości różni się od wartości kona-rodzica:'") + " " + Format(Parent.Currency, NStr("en = 'BF=No; BT=Yes'; pl = 'BF=Wyłączono; BT=Włączono'")), Enums.AlertType.Error, Cancel,ThisObject);
		EndIf;
		
		For Each ParentExtDimensionType In Parent.ExtDimensionTypes Do
			
			If ExtDimensionTypes.Count() < ParentExtDimensionType.LineNumber Then
				Alerts.AddAlert(NStr("en = 'First ext dimenstions of account should be the same as in parent''s account. Lack of ext dimension'; pl = 'Pierwsze analityki konta powinny się zgadzać z analityką kona-rodzica. Brakuje analityki'") + " " + ParentExtDimensionType.LineNumber, Enums.AlertType.Error, Cancel,ThisObject);
				Break;
			EndIf;
			
			ExtDimensionType = ExtDimensionTypes[ParentExtDimensionType.LineNumber - 1];
			
			If Alerts.IsNotEqualValue(ExtDimensionType.ExtDimensionType, ParentExtDimensionType.ExtDimensionType) Then
				Alerts.AddAlert(NStr("en = 'Ext dimenstion type should be the same as in parent''s account. Line'; pl = 'Typ analityki konta powinien się zgadzać z analityką kona-rodzica. Wiersz'") + " " + ParentExtDimensionType.LineNumber, Enums.AlertType.Error, Cancel,ThisObject);
			EndIf;
			
			If Alerts.IsNotEqualValue(ExtDimensionType.TurnoversOnly, ParentExtDimensionType.TurnoversOnly) Then
				Alerts.AddAlert(NStr("en = 'Turnovers only flag should be the same as in parent''s account. Line'; pl = 'Cecha Tylko obroty powinna się zgadzać z kontem-rodzicem. Wiersz'") + " " + ParentExtDimensionType.LineNumber, Enums.AlertType.Error, Cancel,ThisObject);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// IF ACCOUNT IS IN RECODRS
	If Not Ref.IsEmpty() Then // existing account is modified
		
		//AttributesToBeCheckedStructure = New Structure("Parent, BalanceType," + ?(NotValid, "", "Code,") + " Purpose, Currency");
		AttributesToBeCheckedStructure = New Structure("Parent, BalanceType, Code, Purpose, Currency");
		AttributesToBeCheckedString = "";
		AccountAttributesWasChanged = False;
		For Each KeyAndValue In AttributesToBeCheckedStructure Do
			
			If ThisObject["NotValid"] <> Ref["NotValid"] And KeyAndValue.Key = "Code" Then
				AccountAttributesWasChanged = False;
			ElsIf ThisObject[KeyAndValue.Key] <> Ref[KeyAndValue.Key] Then
				AccountAttributesWasChanged = True;
			EndIf;
			
			If KeyAndValue.Key = "Parent" Then
				AttributesToBeCheckedString = AttributesToBeCheckedString + NStr("en = 'Parent account'; pl = 'Konto-rodzic'") + ", ";
			ElsIf KeyAndValue.Key = "Code" Then
				AttributesToBeCheckedString = AttributesToBeCheckedString + NStr("en='Code';pl='Kod';ru='Код'") + ", ";
			ElsIf KeyAndValue.Key = "Currency" Then
				AttributesToBeCheckedString = AttributesToBeCheckedString + Metadata().AccountingFlags[KeyAndValue.Key].Synonym + ", ";
			Else
				AttributesToBeCheckedString = AttributesToBeCheckedString + Metadata().Attributes[KeyAndValue.Key].Synonym + ", ";
			EndIf;
			
		EndDo;
		AttributesToBeCheckedString = Left(AttributesToBeCheckedString, StrLen(AttributesToBeCheckedString) - 2);
		
		AccountExtDimensionsWasChanged = False;
		For Each ExtDimensionType In ExtDimensionTypes Do
			
			If Ref.ExtDimensionTypes.Count() < ExtDimensionType.LineNumber Then
				AccountExtDimensionsWasChanged = True;
				Break;
			EndIf;
			
			RefExtDimensionType = Ref.ExtDimensionTypes[ExtDimensionType.LineNumber - 1];
			If ExtDimensionType.ExtDimensionType <> RefExtDimensionType.ExtDimensionType
				Or ExtDimensionType.TurnoversOnly <> RefExtDimensionType.TurnoversOnly Then
				AccountExtDimensionsWasChanged = True;
				Break;
			EndIf;
			
		EndDo;
		
		If AccountAttributesWasChanged Or AccountExtDimensionsWasChanged Then
			
			Query = New Query;
			Query.Text = "SELECT TOP 1
			             |	Bookkeeping.Period
			             |FROM
			             |	AccountingRegister.Bookkeeping AS Bookkeeping
			             |WHERE
			             |	Bookkeeping.Account = &Account";
			
			Query.SetParameter("Account", Ref);
			AccountIsInRecords = Not Query.Execute().IsEmpty();
			
			If AccountIsInRecords Then
				
				If AccountAttributesWasChanged Then
					Alerts.AddAlert(NStr("en = 'If this account was already used in bookkeeping records you cann''t change these attributes:'; pl = 'Dla konta, które zostało użyte w dekretacjach księgowych nie wolno zmieniać następujących artybutów:'") + " " + AttributesToBeCheckedString, Enums.AlertType.Error, Cancel,ThisObject);
				EndIf;
				
				If AccountExtDimensionsWasChanged Then
					Alerts.AddAlert(NStr("en = 'If this account was already used in bookkeeping records you cann''t change ext dimensions.'; pl = 'Dla konta, które zostało użyte w dekretacjach księgowych nie wolno zmieniać analityk.'"), Enums.AlertType.Error, Cancel,ThisObject);
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
		
	
EndFunction

Function ExtDimensionTypesChecks(Cancel = Undefined) Export 
	
	For Each ExtDimensionType In ExtDimensionTypes Do
		
		MessageTextBegin = NStr("en='Ext dimension';pl='Analityka';ru='Аналитика'") + " " + TrimAll(ExtDimensionType.LineNumber) + ". ";
		
		If ValueIsNotFilled(ExtDimensionType.ExtDimensionType) Then
			Alerts.AddAlert(MessageTextBegin + NStr("en = 'Fill ext dimension type value.'; pl = 'Wypełnij wartość typu analityki.'"), Enums.AlertType.Error, Cancel,ThisObject);
		EndIf;
		
	EndDo;
	
EndFunction

Procedure AdjustExtDimensions(AdjustingExtDimensionType, AdjustingExtDimensionMandatory, AdjustingExtDimensionIndex, Cancel)
	
	If AdjustingExtDimensionType.IsEmpty() Then
		
		If ExtDimensionTypes.Count() > AdjustingExtDimensionIndex Then
			ExtDimensionTypes.Delete(AdjustingExtDimensionIndex);
		EndIf;
		
	Else
		
		If AdjustingExtDimensionIndex > 0 And ThisObject["ExtDimension" + AdjustingExtDimensionIndex + "Type"].IsEmpty() Then
			Alerts.AddAlert(Alerts.ParametrizeString(NStr("en = 'You can leave empty only last ext dimensions for account. Fill ext dimension %P1 or change the order of ext dimensions.'; pl = 'Można pozostawić puste tylko ostatnie analityki konta. Wypełnij wartość analityki %P1 lub zmień kolejność analityk.'"), New Structure("P1", AdjustingExtDimensionIndex + 1)), Enums.AlertType.Error, Cancel, ThisObject);
		EndIf;
		
		If ExtDimensionTypes.Count() > AdjustingExtDimensionIndex Then
			ExtDimensionType = ExtDimensionTypes[AdjustingExtDimensionIndex];
		Else
			ExtDimensionType = ExtDimensionTypes.Add();
		EndIf;
		
		ExtDimensionType.ExtDimensionType = AdjustingExtDimensionType;
		ExtDimensionType.Mandatory        = AdjustingExtDimensionMandatory;
		ExtDimensionType.TurnoversOnly    = False;
		ExtDimensionType.Amount           = True;
		ExtDimensionType.Quantity         = Quantity;
		ExtDimensionType.Currency         = Currency;
		
	EndIf;
	
EndProcedure
