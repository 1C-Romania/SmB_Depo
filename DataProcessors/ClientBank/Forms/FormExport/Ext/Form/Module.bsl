////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Imports the form settings.
// If settings are imported during form attribute
// change, for example for new company, it shall be checked
// whether extension for file handling is enabled.
//
// Data in attributes of the processed object will be a flag of connection failure:
// ExportFile, ImportFile
//
&AtServer
Procedure ImportFormSettings()
	
	Settings = SystemSettingsStorage.Load("DataProcessor.ClientBank.Form.DefaultForm/" + GetURL(Object.BankAccount), "ExportingInSberbank");
	
	If Settings <> Undefined Then
		
		Object.Application = Settings.Get("Application");
		Object.Encoding = Settings.Get("Encoding");
		Object.FormatVersion = Settings.Get("FormatVersion");
		If Not ValueIsFilled(Object.Encoding) Then
			Object.Encoding = "Windows";
		EndIf;
		If Not ValueIsFilled(Object.FormatVersion) Then
			Object.FormatVersion = "1.02";
		EndIf;
		
	EndIf;
	
EndProcedure // ImportFormSettings()

// Function checks the correctness of the form attribute filling.
//
&AtClient
Function CheckFillOfFormAttributes(DirectExchangeWithBanks = False)
	
	CheckResultOk = True;
	
	// Attributes filling check.
	If Not ValueIsFilled(Object.StartPeriod) Then
		MessageText = NStr("en='Beginning period is required!';ru='Не заполнен начальный период!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "StartPeriod", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.EndPeriod) Then
		MessageText = NStr("en='Ending period is required!';ru='Не заполнен конечный период!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "EndPeriod", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.Company) Then
		MessageText = NStr("en='Company is required!';ru='Не заполнена организация!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "Company", CheckResultOk);
	EndIf;
	If Not ValueIsFilled(Object.BankAccount) Then
		MessageText = NStr("en='Bank account is required!';ru='Не заполнен банковский счет!'");
		SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "BankAccount", CheckResultOk);
	EndIf;
	
	If Not DirectExchangeWithBanks Then
		If Not ValueIsFilled(Object.Application) Then
			MessageText = NStr("en='Receiver application is not filled out.';ru='Не заполнена программа приемник!'");
			SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "Application", CheckResultOk);
		EndIf;
		If Not ValueIsFilled(Object.Encoding) Then
			MessageText = NStr("en='Encoding is required!';ru='Не заполнена кодировка!'");
			SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "Encoding", CheckResultOk);
		EndIf;
		If Not ValueIsFilled(Object.FormatVersion) Then
			MessageText = NStr("en='There is no exchange format version!';ru='Не указана версия формата обмена!'");
			SmallBusinessClient.ShowMessageAboutError(ThisForm, MessageText, , , "FormatVersion", CheckResultOk);
		EndIf;
	EndIf;
	
	Return CheckResultOk;
	
EndFunction // CheckFillFormAttributes()

// Function checks the data correctness for export.
//
&AtServer
Function CheckForCorrectnessAndBlankExportValue(DocumentRow)
	
	TaxTransfer          = False;
	PayerIndirectPayments = False;
	RecipientIndirectSettlements  = False;
	TaxTransfer          = (DocumentRow.OperationKind = Enums.OperationKindsPaymentOrder.TaxTransfer);
	PayerIndirectPayments = ValueIsFilled(DocumentRow.CompanySettlementsBank);
	RecipientIndirectSettlements  = ValueIsFilled(DocumentRow.CounterpartySettlementsBank);
	Payer = "Company";
	Recipient = "Counterparty";
	AttributesPaymentDocumentExportBasic = "Number,Date,DocumentAmount";
	AttributesPaymentDocumentExportPayer = Payer + "Account," + Payer + "," + Payer + "TIN";
	AttributesPaymentDocumentExportTNRPayer = Payer + "BankAccount," + Payer + "SettlementBank," + Payer + "BankCity," + Payer + "BankPCBIC";
	AttributesPaymentDocumentExportRecipient = Recipient + "Account," + Recipient + "," + Recipient + "TIN";
	AttributesPaymentDocumentExportTNRRecipient = Recipient + "BankAccount," + Recipient + "SettlementBank," + Recipient + "BankCity," + Recipient + "BankPCBIC";
	AttributesExDockPlBudgetPayment = "AuthorStatus,PayerKPP,PayeeKPP,BKCode,OKATOCode,BasisIndicator,PeriodIndicator,NumberIndicator,DateIndicator,TypeIndicator";
	
	StringAttributes = "%AttributesPaymentDocumentExportBasic%,%AttributesPaymentDocumentExportPayer%,%AttributesPaymentDocumentExportTNRPayer%%AttributesPaymentDocumentExportRecipient%,%AttributesPaymentDocumentExportTNRRecipient%";
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportBasic%", AttributesPaymentDocumentExportBasic);
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportPayer%", AttributesPaymentDocumentExportPayer);
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportTNRPayer%", ?(PayerIndirectPayments, AttributesPaymentDocumentExportTNRPayer + ",", ""));
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportRecipient%", AttributesPaymentDocumentExportRecipient);
	StringAttributes = StrReplace(StringAttributes, "%AttributesPaymentDocumentExportTNRRecipient%", ?(RecipientIndirectSettlements, AttributesPaymentDocumentExportTNRRecipient + ",", ""));
	
	ExportIsNotEmpty = CreateMapFromString(StringAttributes);
	
	For Each Property IN ExportIsNotEmpty Do
		CheckForBlankExportValue(DocumentRow, Property.Key);
	EndDo;
	If TaxTransfer Then
		CheckTaxAttributesFill(DocumentRow);
	EndIf;
	CheckForCorrectionNumbernessOnDump(DocumentRow);
	
EndFunction // CheckForCorrectnessAndBlankExportValue()

// Procedure checks the blank data value for export.
//
&AtServer
Procedure CheckForBlankExportValue(RowExporting, PropertyName)
	
	If Not ValueIsFilled(RowExporting[TrimAll(PropertyName)]) Then
		RowRemark = NStr("en='""%PropertyName%"" is not filled!';ru='Не заполнено ""%ИмяСвойства%""!'");
		RowRemark = StrReplace(RowRemark, "%PropertyName%", PropertyName);
		AddComment(RowExporting, 3, RowRemark);
		SetReadiness(RowExporting.Readiness, 4);
	EndIf;
	
EndProcedure // CheckForBlankExportValue()

// Procedure checks the number correctness for export.
//
&AtServer
Procedure CheckForCorrectionNumbernessOnDump(RowExporting)
	
	Value = TrimAll(RowExporting.Number);
	Try
		If Number(String(Number(Right(Value, 3)))) = 0 Then
			AddComment(RowExporting, 4, NStr("en='Number should end with three digits which are not ""000""!';ru='Номер должен оканчиваться на три цифры и не на ""000""!'"));
		EndIf;
	Except
		AddComment(RowExporting, 4, NStr("en='Number should end with three digits which are not ""000""!';ru='Номер должен оканчиваться на три цифры и не на ""000""!'"));
	EndTry;
	
EndProcedure // CheckForCorrectionNumbernessOnExport()

// Function checks the correctness of the tax attribute filling.
//
&AtServer
Function CheckTaxAttributesFill(RowExporting)
	
	Error = New ValueList();
	P101 = TrimAll(RowExporting.AuthorStatus);
	P104 = TrimAll(RowExporting.BKCode);
	P105 = TrimAll(RowExporting.OKATOCode);
	P106 = TrimAll(RowExporting.BasisIndicator);
	P107 = ?(
		IsBlankString(TrimAll(StrReplace(RowExporting.PeriodIndicator , ".", ""))) = 1,
		"",
		RowExporting.PeriodIndicator
	);
	P107 = ?(
		TrimAll(StrReplace(RowExporting.PeriodIndicator, ".", "")) = "0",
		"",
		RowExporting.PeriodIndicator
	);
	P108 = TrimAll(RowExporting.NumberIndicator);
	P109 = ?(
		Not ValueIsFilled(RowExporting.DateIndicator),
		"0",
		String(RowExporting.DateIndicator)
	);
	P110 = TrimAll(RowExporting.TypeIndicator);
	If (Find("01,02,03,04,05,06,07,08,09,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26", P101) = 0)
	 OR (IsBlankString(TrimAll(P101))) Then
		AddComment(
			RowExporting,
			3,
			NStr("en='Invalid value of the Preparer status attribute field for payments to budget on the ""Fund transfer to the budget"" tab.';ru='Неверное значение поля реквизита для платежей в бюджет ""Статус составителя"" на закладке ""Перечисление в бюджет"".'")
		);
		SetReadiness(RowExporting.Readiness, 4);
	EndIf;
	If Not(SmallBusinessClientServer.EmptyBCCAllowed(RowExporting.TransferToBudgetKind, RowExporting.CounterpartyAccountNo, RowExporting.Date))
		 AND (StrReplace(P104, "0", "") = "") AND (Find("06, 07", P101) = 0) Then
		AddComment(
			RowExporting,
			3,
			NStr("en='The BCC field on the ""Fund transfer to the budget"" tab is not filled in.';ru='Не заполнено поле ""КБК"" на закладке ""Перечисление в бюджет"".'")
		);
		SetReadiness(RowExporting.Readiness, 4);
	EndIf;
	If IsBlankString(P105) Then
		If RowExporting.Date >= '20140101' Then // OKTMO acts in any case from 01/01/2014 
			AddComment(
				RowExporting,
				3,
				NStr("en='The OKTMO code field on the ""Fund transfer to the budget"" tab is not filled in.';ru='Не заполнено поле ""Код ОКТМО"" на закладке ""Перечисление в бюджет"".'")
			);
		Else
			AddComment(
				RowExporting,
				3,
				NStr("en='The OKATO code field on the ""Fund transfer to the budget"" tab is not filled in.';ru='Не заполнено поле ""Код ОКАТО"" на закладке ""Перечисление в бюджет"".'")
			);
		EndIf;
		SetReadiness(RowExporting.Readiness, 4);
	EndIf;
	
	// We check it depending on preparer status.
	If P101 = "08" Then
		If StrReplace(P106, "0", "") <> "" Then 
			AddComment(
				RowExporting,
				3,
				NStr("en='When the preparer status is ""08"", specify ""0"" in the Payment reason field on the ""Fund transfer to the budget"" tab.';ru='При статусе составителя ""08"" следует указать ""0"" в поле ""Основание платежа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P107, "0", "") <> "" Then
			AddComment(
				RowExporting,
				3,
				NStr("en='When preparer status is ""08"", specify ""0"" in the ""Tax period"" field on the ""Fund transfer to the budget"" tab.';ru='При статусе составителя ""08"" следует указать ""0"" в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P108, "0", "") <> "" Then
			AddComment(
				RowExporting,
				3,
				NStr("en='When the preparer status is ""08"", the Document number field on the ""Fund transfer to the budget"" tab should be empty.';ru='При статусе составителя ""08"" не следует заполнять поле ""Номер документа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P109, "0", "") <> "" Then
			AddComment(
				RowExporting,
				3,
				NStr("en='When the preparer status is ""08"", the Document date field on the ""Fund transfer to the budget"" tab should be empty.';ru='При статусе составителя ""08"" не следует заполнять поле ""Дата документа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P110, "0", "") <> "" Then
			AddComment(
				RowExporting,
				3,
				NStr("en='When preparer status is ""08"", specify ""0"" in the Payment type field on the ""Fund transfer to the budget"" tab.';ru='При статусе составителя ""08"" следует указать ""0"" в поле ""Тип платежа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
	Else
		// We check depending on the payment basis.
		If StrReplace(TrimAll(P106), "0", "") = "" Then
			If StrReplace(P107, "0", "") <> "" Then
				If Not ValueIsFilled(P107) Then
					AddComment(
						RowExporting,
						3,
						NStr("en='The Tax period field value on the ""Fund transfer to the budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
					);
					SetReadiness(RowExporting.Readiness, 4);
				EndIf;
			EndIf;
		ElsIf StrLen(P106) <> 2 Then
			If StrReplace(P107, "0", "") <> "" Then
				If Not ValueIsFilled(P107) Then
					AddComment(
						RowExporting,
						3,
						NStr("en='The Tax period field value on the ""Fund transfer to the budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
					);
					SetReadiness(RowExporting.Readiness, 4);
				EndIf;
			EndIf;
		ElsIf Find("AP, AR", P106) > 0 Then
			If StrReplace(P107, "0", "") <> "" Then
				AddComment(
					RowExporting,
					3,
					NStr("en='When the payment reason is ""AA"" or ""EA"", specify ""0"" in the Tax period field on the ""Fund transfer to the budget"" tab.';ru='При основании платежа ""АП"" или ""АР"" следует указать ""0"" в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
				);
				SetReadiness(RowExporting.Readiness, 4);
			EndIf;
		ElsIf Find("TP, RS, OT, PT, VU, PR, PB, ZT, IN", P106) > 0 Then
			If StrReplace(P107, "0", "") <> "" Then
				If Not ValueIsFilled(P107) Then
					AddComment(
						RowExporting,
						3,
						NStr("en='The Tax period field value on the ""Fund transfer to the budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
					);
					SetReadiness(RowExporting.Readiness, 4);
				EndIf;
			EndIf;
		ElsIf Find("CP, ZD ", P106) > 0 Then
			If StrReplace(P107, "0", "") <> "" Then
				DD = Mid((P107), 1, 2);
				MM = Mid((P107), 4, 2);
				yy = Mid((P107), 7, 4);
				If Not MM = "" Then
					MM = Number(Mid((P107), 4, 2));
				Else
					MM = 0;
				EndIf;
				If Not yy = "" Then
					yy = Number(Mid((P107), 7, 4));
				Else
					yy = 0;
				EndIf;
				If (Find("D1, D2, D3, MS", DD) > 0) Then
					If (MM < 1)
					 OR (MM > 12)
					 OR (yy < 2000)
					 OR (StrLen(P107) - StrLen(StrReplace(P107, ".", "")) <> 2) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='The Tax period field value on the ""Fund transfer to the budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						);
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				ElsIf (Find("KV", DD) > 0) Then
					If (MM < 1)
					 OR (MM > 4)
					 OR (yy < 2000)
					 OR (StrLen(P107) - StrLen(StrReplace(P107, ".", "")) <> 2) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='The Tax period field value on the ""Fund transfer to the budget"" tab is invalid.';ru='Неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						);
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				ElsIf (Find("PL", DD) > 0) Then
					If (MM < 1)
					 OR (MM > 2)
					 OR (yy < 2000)
					 OR (StrLen(P107) - StrLen(StrReplace(P107, ".", "")) <> 2) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='The Tax period field value on the ""Fund transfer to the budget"" tab is invalid.';ru='Неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						);
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				ElsIf (Find("GD", DD) > 0) Then
					If (MM <> 0)
					 OR (yy < 2000)
					 OR (StrLen(P107) - StrLen(StrReplace(P107, ".", "")) <> 2) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='The Tax period field value on the ""Fund transfer to the budget"" tab is invalid.';ru='Неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						);
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				Else
					If Not ValueIsFilled(P107) Then
						AddComment(
							RowExporting,
							3,
							NStr("en='The Tax period field value on the ""Fund transfer to the budget"" tab might be invalid.';ru='Возможно, неверно указано значение в поле ""Налоговый период"" на закладке ""Перечисление в бюджет"".'")
						); 
						SetReadiness(RowExporting.Readiness, 4);
					EndIf;
				EndIf;
			EndIf;
			If StrReplace(P108, "0", "") <> "" Then
				AddComment(
					RowExporting,
					3,
					NStr("en='When the payment reason is ""TP"" or ""ZD"", specify ""0"" in the Document number field on the ""Fund transfer to the budget"" tab.';ru='При основании платежа ""ТП"" или ""ЗД"" необходимо указывать ""0"" в поле ""Номер документа"" на закладке ""Перечисление в бюджет"".'")
				);
				SetReadiness(RowExporting.Readiness, 4);
			EndIf;
			If Find("ZD ", P106) > 0 Then
				If StrReplace(P109, "0", "") <> "" Then
					AddComment(
						RowExporting,
						3,
						NStr("en='When payment reason is ""ZD"", the Document date field on the ""Fund transfer to the budget"" tab should be empty.';ru='При основании платежа ""ЗД"" не должно заполняться поле ""Дата документа"" на закладке ""Перечисление в бюджет"".'")
					);
					SetReadiness(RowExporting.Readiness, 4);
				EndIf;
			EndIf;
		ElsIf Find("BF, DE, PO, CC, ID, CO, TY, BD, IN, KP", P106) > 0 Then
		Else
			AddComment(
				RowExporting,
				3,
				NStr("en='The Payment reason field value on the ""Fund transfer to the budget"" tab is invalid.';ru='Неверно указано значение в поле ""Основание платежа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
		If StrReplace(P110, "0", "") = "" Then
		ElsIf Find("TF, AB, PE, PC, AS, ASH, ISH, PL, GP, VZ, PCS, ZD", P110) > 0 Then
		Else
			AddComment(
				RowExporting,
				3,
				NStr("en='The Payment type field value on the ""Fund transfer to the budget"" tab is invalid.';ru='Неверно указано значение в поле ""Тип платежа"" на закладке ""Перечисление в бюджет"".'")
			);
			SetReadiness(RowExporting.Readiness, 4);
		EndIf;
	EndIf;
	
	// We are displaying a found error list.
	For Num = 0 To Error.Count() - 1 Do
		MessageText = Error.Get(Num);
		SmallBusinessServer.ShowMessageAboutError(ThisForm, MessageText);
	EndDo;
	
	Return Error;
	
EndFunction // CheckTaxAttributesFill()

// Procedure checks sets readiness.
//
&AtServer
Procedure SetReadiness(CurrentReadiness, NewReadiness)
	
	If ValueIsFilled(CurrentReadiness)
	   AND CurrentReadiness < NewReadiness Then
		CurrentReadiness = NewReadiness;
	ElsIf Not ValueIsFilled(CurrentReadiness) Then
		CurrentReadiness = NewReadiness;
	EndIf;
	
EndProcedure // SetReadiness()

// Procedure adds a comment.
//
&AtServer
Procedure AddComment(DocumentStructure, NewReadiness, NoticeText)
	
	SetReadiness(DocumentStructure.Readiness, NewReadiness);
	AddToString(DocumentStructure.ErrorsDescriptionFull, NoticeText);
	
EndProcedure // AddComment()

// Procedure adds a row.
//
&AtServer
Procedure AddToString(Buffer, NewRow)
	
	If IsBlankString(Buffer) Then
		Buffer = NewRow;
	Else
		Buffer = Buffer + Chars.LF + NewRow;
	EndIf;
	
EndProcedure // AddToString()

// Function creates a match from string.
//
&AtServer
Function CreateMapFromString(Val StringThroughComma)
	
	NewMap = New Map;
	SeparatorPosition = Find(StringThroughComma, ",");
	While SeparatorPosition > 0 Do
		NameItema = Left(StringThroughComma, SeparatorPosition - 1);
		NewMap.Insert(NameItema, True);
		StringThroughComma = Mid(StringThroughComma, SeparatorPosition + 1);
		SeparatorPosition = Find(StringThroughComma, ",");
	EndDo;
	If StrLen(StringThroughComma) > 0 Then
		NewMap.Insert(StringThroughComma, True);
	EndIf;
	
	Return NewMap;
	
EndFunction // CreateMatchFromString()

// Procedure fills out a table for exporting.
//
&AtServer
Procedure FillDump()
	
	Object.Company = Object.BankAccount.Owner;
	
	Query = New Query(
	"SELECT
	|	PaymentOrder.Date,
	|	PaymentOrder.Number,
	|	PaymentOrder.PaymentDestination,
	|	PaymentOrder.PaymentKind,
	|	PaymentOrder.Ref AS Document,
	|	PaymentOrder.DateIndicator,
	|	PaymentOrder.NumberIndicator,
	|	PaymentOrder.BasisIndicator,
	|	PaymentOrder.TypeIndicator,
	|	PaymentOrder.PeriodIndicator,
	|	PaymentOrder.AuthorStatus,
	|	PaymentOrder.DocumentAmount,
	|	PaymentOrder.Counterparty,
	|	PaymentOrder.OperationKind,
	|	PaymentOrder.PaymentPriority,
	|	PaymentOrder.PayerText,
	|	PaymentOrder.PayeeText,
	|	PaymentOrder.TransferToBudgetKind,
	|	PaymentOrder.PayerTIN AS PayerTIN,
	|	PaymentOrder.PayerKPP AS PayerKPP,
	|	PaymentOrder.PayeeTIN AS PayeeTIN,
	|	PaymentOrder.PayeeKPP AS PayeeKPP,
	|	PaymentOrder.BKCode,
	|	PaymentOrder.OKATOCode,
	|	PaymentOrder.Company.DescriptionFull AS Company,
	|	PaymentOrder.Company.PayerDescriptionOnTaxTransfer AS CompanyTaxTransfer,
	|	PaymentOrder.Company.TIN AS CompanyTIN,
	|	PaymentOrder.Company.KPP AS CompanyKPP,
	|	PaymentOrder.BankAccount AS CompanyAccount,
	|	PaymentOrder.BankAccount.AccountNo AS CompanyAccountNo,
	|	PaymentOrder.BankAccount.Bank.Code AS CompanyBankBIC,
	|	PaymentOrder.BankAccount.Bank AS CompanyBank,
	|	PaymentOrder.BankAccount.Bank.CorrAccount AS CompanyBankAcc,
	|	PaymentOrder.BankAccount.Bank.City AS CompanyBankCity,
	|	PaymentOrder.BankAccount.AccountsBank AS CompanySettlementsBank,
	|	PaymentOrder.BankAccount.AccountsBank.City AS CompanyBankProcessingCenterCity,
	|	PaymentOrder.BankAccount.AccountsBank.Code AS CompanyBankProcessingCenterBIC,
	|	PaymentOrder.BankAccount.AccountsBank.CorrAccount AS CompanyBankProcessingCenterCorrAccount,
	|	PaymentOrder.Counterparty.TIN AS CounterpartyTIN,
	|	PaymentOrder.Counterparty.KPP AS CounterpartyKPP,
	|	PaymentOrder.CounterpartyAccount AS CounterpartyAccount,
	|	PaymentOrder.CounterpartyAccount.AccountNo AS CounterpartyAccountNo,
	|	PaymentOrder.CounterpartyAccount.Bank AS CounterpartyBank,
	|	PaymentOrder.CounterpartyAccount.Bank.CorrAccount AS CounterpartyBankAcc,
	|	PaymentOrder.CounterpartyAccount.Bank.City AS CounterpartyBankCity,
	|	PaymentOrder.CounterpartyAccount.AccountsBank AS CounterpartySettlementsBank,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.City AS CounterpartyBankProcessingCenterCity,
	|	PaymentOrder.CounterpartyAccount.Bank.Code AS CounterpartyBankBIC,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.Code AS CounterpartyBankProcessingCenterBIC,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.CorrAccount AS CounterpartyBankProcessingCenterCorrAccount,
	|	PaymentOrder.PaymentIdentifier AS PaymentIdentifier,
	|	ISNULL(EDStates.EDVersionState, VALUE(Enum.EDVersionsStates.EmptyRef)) AS EDStatus,
	|	""Payment order"" AS DocumentKind,
	|	CAST("""" AS String(255)) AS ErrorsDescriptionFull,
	|	0 AS Readiness,
	|	0 AS PictureNumber,
	|	0 AS DocumentAmountAllocated,
	|	TRUE AS Exporting
	|FROM
	|	Document.PaymentOrder AS PaymentOrder
	|		LEFT JOIN InformationRegister.EDStates AS EDStates
	|		ON PaymentOrder.Ref = EDStates.ObjectReference
	|WHERE
	|	PaymentOrder.Company = &Company
	|	AND PaymentOrder.BankAccount = &BankAccount
	|	AND PaymentOrder.Date between &StartPeriod AND &EndPeriod
	|	AND PaymentOrder.DeletionMark = FALSE
	|
	|ORDER BY
	|	PaymentOrder.Date,
	|	Document");
	
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("BankAccount", Object.BankAccount);
	Query.SetParameter("StartPeriod", BegOfDay(Object.StartPeriod));
	Query.SetParameter("EndPeriod", EndOfDay(Object.EndPeriod));
	
	Exporting = Query.Execute().Unload();
	
	For Each DocumentRow IN Exporting Do
		CheckForCorrectnessAndBlankExportValue(DocumentRow);
		DocumentRow.Exporting = IsBlankString(DocumentRow.ErrorsDescriptionFull);
		DocumentRow.PaymentDestination = TrimAll(DocumentRow.PaymentDestination);
		DocumentRow.PictureNumber = ?(IsBlankString(DocumentRow.ErrorsDescriptionFull), 0, 1);
		FillAmountsAllocatedAtServer(DocumentRow);
	EndDo;
	
	Object.Exporting.Load(Exporting);
	
	DirectExchangeWithBanksAgreement = Undefined;
	If ValueIsFilled(Object.BankAccount) Then
		
		If GetFunctionalOption("UseEDExchangeWithBanks") Then
			
			Query = New Query();
			Query.Parameters.Insert("BankAccount", Object.BankAccount);
			Query.Parameters.Insert("Company", Object.Company);
			Query.Text =
			"SELECT
			|	EDUsageAgreements.Ref AS DirectExchangeWithBanksAgreement,
			|	EDUsageAgreements.Counterparty
			|FROM
			|	Catalog.BankAccounts AS BankAccounts
			|		INNER JOIN Catalog.EDUsageAgreements AS EDUsageAgreements
			|		ON BankAccounts.Bank = EDUsageAgreements.Counterparty
			|WHERE
			|	BankAccounts.Ref = &BankAccount
			|	AND EDUsageAgreements.Company = &Company
			|	AND EDUsageAgreements.AgreementStatus = VALUE(Enum.EDAgreementsStatuses.Acts)";
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				DirectExchangeWithBanksAgreement = Selection.DirectExchangeWithBanksAgreement;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // FillExport()

// Procedure exports data to the file.
//
&AtServer
Function DonwloadDataToFile()
	
	DumpStream = FormAttributeToValue("Object").Unload(FileOperationsExtensionConnected, UUID);
	
	Return DumpStream;
	
EndFunction // ExportDataToFile()

// Function saves a swap file.
//
&AtClient
Procedure SaveExportFile(DumpStream)
	
	#If WebClient Then
		ThisIsWebClient = True;
	#Else
		ThisIsWebClient = False;
	#EndIf
	
	Try
		
		ExportOnline = Object.ExportFile = "1c_to_kl.txt" OR ThisIsWebClient;
		
		Result = GetFile(DumpStream, Object.ExportFile, ExportOnline);
		
		// We check those documents that were successfully exported.
		If Result <> Undefined Then
			If Result Then
				//( elmi #17 (112-00003) 
				//For Each SectionRow IN Object.Export Do
				For Each SectionRow IN Object.Exporting Do
				//) elmi
				
					If SectionRow.Readiness = - 2 Then
						SectionRow.Readiness = - 1;
					EndIf;
				EndDo;
				If ExportOnline Then
					MessageText = NStr("en='Data have been successfully exported to the file.';ru='Данные успешно выгружены в файл.'");
				Else
					MessageText = NStr("en='Data is successfully exported to the file ';ru='Данные успешно выгружены в файл '") + Object.ExportFile + ".";
				EndIf;
			Else
				MessageText = NStr("en='Operation canceled';ru='Операция отменена'");
			EndIf;
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		
	Except
		
		MessageText = NStr("en='Writing data to the file is failed. The disk may be write-protected.';ru='Не удалось записать данные в файл. Возможно, диск защищен от записи.'");
		ShowMessageBox(Undefined,MessageText);
		
	EndTry
	
EndProcedure // SaveSwapFile()

// Procedure sets flags.
//
&AtClient
Procedure SetFlags(Table, Field, ValueOfFlag)
	
	For Each String IN Table Do
		String[Field] = ValueOfFlag;
		FillAmount76AtClient(String)
	EndDo;
	
EndProcedure // SetFlags()

// Function returns the found tree item.
//
&AtServer
Function FindTreeItem(TreeItems, ColumnName, RequiredValue)
	
	For Num = 0 To TreeItems.Count() - 1 Do
		
		TreeItem = TreeItems.Get(Num);
		
		If TreeItem[ColumnName] = RequiredValue Then
			Return TreeItem;
		EndIf;
		
		If TreeItem.GetItems().Count() > 0 Then
			
			SearchResult = FindTreeItem(TreeItem.GetItems(), ColumnName, RequiredValue);
			
			If Not SearchResult = Undefined Then
				Return SearchResult;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction // FindTreeItem()

&AtServer
Procedure FormManagementOnServer()

	DirectExchangeWithBanks = ValueIsFilled(DirectExchangeWithBanksAgreement);
	
	Items.StatementExportGroup.CurrentPage = ?(DirectExchangeWithBanks, Items.StatementExportGroupThroughED, Items.StatementExportGroupInFile);
	
	Items.Export.Visible = Not DirectExchangeWithBanks;
	Items.Export.DefaultButton = Not DirectExchangeWithBanks;
	Items.SendToBank.Visible = DirectExchangeWithBanks;
	Items.SendToBank.DefaultButton = DirectExchangeWithBanks;
	Items.StatementExportDescriptionGroupThroughED.Visible = DirectExchangeWithBanks;
	Items.ExportEDState.Visible = DirectExchangeWithBanks;
	
	If GetFunctionalOption("UseEDExchangeWithBanks")
		AND ValueIsFilled(DirectExchangeWithBanksAgreement) Then
		
		TemplateText = NStr("en='Direct exchange agreement acts from %1: payment orders will be sent in bank by 1C:Company';ru='С %1 действует соглашение о прямом обмене: платежные поручения будут отправлены в банк из 1С:Управление небольшой фирмой'");
		LabelText = StringFunctionsClientServer.PlaceParametersIntoString(TemplateText, CommonUse.GetAttributeValue(DirectExchangeWithBanksAgreement, "Counterparty"));
		DirectMessageExchange = LabelText;
	EndIf;

EndProcedure // FormManagementOnServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	If Parameters.Property("Company") Then
		Object.Company = Parameters.Company;
	EndIf;
	
	If Parameters.Property("BankAccountOfTheCompany")
	   AND ValueIsFilled(Parameters.BankAccountOfTheCompany) Then
		Object.BankAccount = Parameters.BankAccountOfTheCompany;
		ThisForm.Title = "Saving of payment orders by bill: " + Parameters.BankAccountOfTheCompany.Description;
	Else
		Items.GroupBankAccountExport.Visible = True;
	EndIf;
	
	If Parameters.Property("ExportFile") Then
		Object.ExportFile = Parameters.ExportFile;
	EndIf;
	
	If Parameters.Property("Application") Then
		Object.Application = Parameters.Application;
	EndIf;
	
	If Parameters.Property("Encoding") Then
		Object.Encoding = Parameters.Encoding;
	EndIf;
	
	If Parameters.Property("FormatVersion") Then
		Object.FormatVersion = Parameters.FormatVersion;
	EndIf;
	
	If Not ValueIsFilled(Object.Company) Then
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			Object.Company = SettingValue;
		Else
			Object.Company = Catalogs.Companies.MainCompany;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.BankAccount) Then
		Object.BankAccount = Object.Company.BankAccountByDefault;
	EndIf;
	
	If Not ValueIsFilled(Object.StartPeriod) Then
		Object.StartPeriod = CurrentDate();
	EndIf;
	
	If Not ValueIsFilled(Object.EndPeriod) Then
		Object.EndPeriod = CurrentDate();
	EndIf;
	
	If Not ValueIsFilled(Object.Encoding) Then
		Object.Encoding = "Windows";
	EndIf;
	
	If Not ValueIsFilled(Object.FormatVersion) Then
		Object.FormatVersion = "1.02";
	EndIf;
	
	If Parameters.Property("DirectExchangeWithBanksAgreement") Then
		DirectExchangeWithBanksAgreement = Parameters.DirectExchangeWithBanksAgreement;
	EndIf;
	
	FillDump();
	ImportFormSettings();
	
	FormManagementOnServer();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	Notification = New NotifyDescription("BeginEnableExtensionFileOperationsEnd", ThisObject, New Structure("FormAttribute", "ImportFile"));
	BeginAttachingFileSystemExtension(Notification);
	If Not ValueIsFilled(Object.ExportFile) Then
		Object.ExportFile = "1c_to_kl.txt";
	EndIf;
	
EndProcedure // OnOpen()

&AtClient
Procedure BeginEnableExtensionFileOperationsEnd(Attached, AdditionalParameters) Export
	
	ThisForm.FileOperationsExtensionConnected = Attached;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - Export command handler.
//
&AtClient
Procedure ExportExecute(Command)
	
	ClearMessages();
	
	If Not CheckFillOfFormAttributes() Then
		
		Return;
		
	EndIf;
	
	If Object.Exporting.Count() > 0 Then
		
		//( elmi #17 (112-00003) 
		ExternalDataProcessorRefs = GetExternalDataProcessor(Object.BankAccount);
		
		If ValueIsFilled(ExternalDataProcessorRefs) Then
   		
			ArrayOfPurposes  = New  Array;
		    ArrayOfPurposes.Insert(0, Object.BankAccount); 

			ExportArray  =  PutToTempStorage(UpLoadTSExporting(), UUID);
			
			ParametersOfDataProcessor = New Structure("CommandID, AdditionalInformationProcessorRef, ArrayOfPurposes, ExportArray, ExecutionResult" ); 
    	    ParametersOfDataProcessor.CommandID                           = "ExportFromClientBankExternalDP";
	        ParametersOfDataProcessor.AdditionalInformationProcessorRef   = ExternalDataProcessorRefs;
	        ParametersOfDataProcessor.ArrayOfPurposes                     = Object.BankAccount;
	        ParametersOfDataProcessor.ExportArray                         = ExportArray;
            ParametersOfDataProcessor.ExecutionResult                     = New Structure("ExportAddress, WarningText" );
			
			//Elmi_SmalBusinessServer.RunCommandOnServer( ParametersOfDataProcessor);
			RunCommandOnServer( ParametersOfDataProcessor);
			
		    Result = ParametersOfDataProcessor.ExecutionResult;
		
		    If Result <> Undefined Then
			   If Result.Property("WarningText") Then
				  If ValueIsFilled(Result.WarningText) Then
					WarningText = Result.WarningText;
				  EndIf;	   
			   EndIf;	
			   If Result.Property("ExportAddress")  Then 
				   SaveExportFile(Result.ExportAddress);
			   EndIf;	   
		    Else		
				   WarningText = NStr("en='Export document list is empty."
"Verify the correctness of the specified banking account and the export period.';ru='Список документов для выгрузки пуст."
"Проверьте правильность указанного банковского счета и периода выгрузки.'")
			EndIf;	
	    //) elmi
		
	    Else 
	    	DumpStream = DonwloadDataToFile();
		    SaveExportFile(DumpStream);
			
		EndIf;	
	Else
		
		ShowMessageBox(Undefined,
			NStr("en='Export document list is empty."
"Verify the correctness of the specified banking account and the export period.';ru='Список документов для выгрузки пуст."
"Проверьте правильность указанного банковского счета и периода выгрузки.'")
		);
		
	EndIf;
	
			
EndProcedure // ExportExecute()

&AtClient
Procedure SendToBank(Command)
	
	ClearMessages();
	
	DirectExchangeWithBanks = ValueIsFilled(DirectExchangeWithBanksAgreement);
	If Not CheckFillOfFormAttributes(DirectExchangeWithBanks) Then
		
		Return;
		
	EndIf;
	
	If Object.Exporting.Count() > 0 Then
		
		DocumentArray = New Array;
		
		For Each String IN Object.Export Do
			If String.Exporting Then
				DocumentArray.Add(String.Document);
			EndIf;
		EndDo;
		
		NotifyDescription = New NotifyDescription("SendToBankEnd", ThisObject);
		ElectronicDocumentsClientOverridable.RunDocumentsPostingCheck(
			DocumentArray, NotifyDescription, ThisObject);
		
	Else
		
		ShowMessageBox(Undefined,
			NStr("en='Export document list is empty."
"Verify the correctness of the specified banking account and the export period.';ru='Список документов для выгрузки пуст."
"Проверьте правильность указанного банковского счета и периода выгрузки.'")
		);
		
	EndIf;
	
EndProcedure // SendToBank()

&AtClient
Procedure SendToBankEnd(DocumentArray, AdditionalParameters) Export
	
	ElectronicDocumentsClient.GenerateSignSendED(DocumentArray);
	
EndProcedure

// Procedure - ExportRefresh command handler.
//
&AtClient
Procedure DumpUpdateRun(Command)
	
	FillDump();
	
EndProcedure // ExportRefreshExecute()

// Procedure - ExportCheckAll command handler.
//
&AtClient
Procedure DumpMarkAllRun(Command)
	
	SetFlags(Object.Export, "Exporting", True);
	
EndProcedure // ExportMarkAllRun()

// Procedure - ExportUncheckAll command handler.
//
&AtClient
Procedure DumpUnmarkAllRun(Command)
	
	SetFlags(Object.Export, "Exporting", False);
	
EndProcedure // ExportUnmarkAllRun()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - Open event handler of the BankAccount input field.
//
&AtClient
Procedure BankAccountOnChange(Item)
	
	FillDump();
	ImportFormSettings();
	FormManagementOnServer();
	
EndProcedure // BankAccountOnChange()

// Procedure - Open event handler of the StartPeriod input field.
//
&AtClient
Procedure StartPeriodOnChange(Item)
	
	FillDump();
	
EndProcedure // StartPeriodOnChange()

// Procedure - Open event handler of the EndPeriod input field.
//
&AtClient
Procedure EndPeriodOnChange(Item)
	
	FillDump();
	
EndProcedure // EndPeriodOnChange()

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTIONS EVENT HANDLERS

// Procedure - Selection event handler of the export tabular section .
//
&AtClient
Procedure ExportSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Field.Name = "ExportExporting" Then
		Items.Exporting.CurrentData.Exporting = Not (Items.Exporting.CurrentData.Exporting);		
	ElsIf Field.Name = "ExportPictureNumber" Then 
		If ValueIsFilled(Items.Exporting.CurrentData.ErrorsDescriptionFull) Then
			ShowMessageBox(Undefined,Items.Exporting.CurrentData.ErrorsDescriptionFull);
		Else
			ShowMessageBox(Undefined,NStr("en='Document is ready for export!';ru='Документ готов к выгрузке!'"));
		EndIf;
	ElsIf Field.Name = "ExportPaymentDestination" Then
		ShowMessageBox(Undefined,Items.Exporting.CurrentData.PaymentDestination);
	Else
		OpenForm("Document.PaymentOrder.ObjectForm",
			New Structure("Key", Items.Exporting.CurrentData.Document),
			Items.Exporting.CurrentData.Document
		);
	EndIf;
	
EndProcedure // ExportSelection()

// Procedure - command handler Setting.
//
&AtClient
Procedure Setting(Command)
	
	OpenForm("DataProcessor.ClientBank.Form.FormSetting",
		New Structure(
			"Script, Application, FormatVersion, DirectExchangeWithBanksAgreement, UUID",
			Object.Encoding, Object.Application, Object.FormatVersion, DirectExchangeWithBanksAgreement, UUID
		)
	);
	
EndProcedure // Setting()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SettingsChange" + UUID Then
		Object.Encoding = Parameter.Encoding;
		Object.Application = Parameter.Application;
		Object.FormatVersion = Parameter.FormatVersion;
	ElsIf EventName = "RefreshStateED" Then
		FillDump();
	EndIf;
	

EndProcedure // NotificationProcessing()

// Filling the amount of marked items.
//
&AtClient
Procedure FillAmount76AtClient(CurRow)
	
	CurRow.DocumentAmountAllocated = ?(CurRow.Exporting, CurRow.DocumentAmount, 0);
	
EndProcedure

// Filling the amount of marked items.
//
&AtServer
Procedure FillAmountsAllocatedAtServer(CurRow)
	
	CurRow.DocumentAmountAllocated = ?(CurRow.Exporting, CurRow.DocumentAmount, 0);
	
EndProcedure

// Procedure - OnChange event handler of the Export field from Export list .
//
&AtClient
Procedure DowloadingExportOnChange(Item)
	
	CurRow = Items.Exporting.CurrentData;
	FillAmount76AtClient(CurRow)
	
EndProcedure // DowloadingExportOnChange()


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


//( elmi #17 (112-00003) 
&AtServer
Function UpLoadTSExporting ()
	
VT = Object.Exporting.Unload();

Return  TransformValueTableIntoArrayOfStructure(VT);


EndFunction	
//) elmi

//( elmi #17 (112-00003) 
&AtServer
Function TransformValueTableIntoArrayOfStructure(vtData) Export
    
    arData = New Array;
	

    For Each StringVT IN vtData Do
    
        StrucStringVT = New Structure;
		
		For Each ColumnName Из vtData.Columns Do
            StrucStringVT.Insert(ColumnName.Name, StringVT[ColumnName.Name]);
        EndDo;
        
        arData.Add(StrucStringVT);
        
    EndDo;
    
    Возврат arData;
    
EndFunction
//) elmi


//( elmi #17 (112-00003) 
&AtServer
Function  GetExternalDataProcessor(Account)
	
	    Return Account.ExternalDataProcessor;
	     
EndFunction
//) elmi


//elmi #17 (112-00003)	
&AtServer
Procedure RunCommandOnServer(ParametersDataProcessors) Export
	
AdditionalReportsAndDataProcessors.RunCommand( ParametersDataProcessors );
	
EndProcedure	
