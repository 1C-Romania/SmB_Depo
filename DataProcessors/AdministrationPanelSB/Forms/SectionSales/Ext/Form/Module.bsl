
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
		
		If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingRetail" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "Group1", 							"Enabled", ConstantsSet.FunctionalOptionAccountingRetail);
			CommonUseClientServer.SetFormItemProperty(Items, "SettingAccountingRetailSalesDetails","Enabled", ConstantsSet.FunctionalOptionAccountingRetail);
			CommonUseClientServer.SetFormItemProperty(Items, "Group2", 							"Enabled", ConstantsSet.FunctionalOptionAccountingRetail);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseCustomerOrderStates" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogCustomerOrderStates",			"Enabled", ConstantsSet.UseCustomerOrderStates);
			CommonUseClientServer.SetFormItemProperty(Items, "CustomerOrdersDefaultStatusSetting","Enabled", Not ConstantsSet.UseCustomerOrderStates);
			
		EndIf;
		
		// DiscountCards
		If AttributePathToData = "ConstantsSet.FunctionalOptionUseDiscountsMarkups" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "FunctionalOptionUseDiscountCards", "Enabled", ConstantsSet.FunctionalOptionUseDiscountsMarkups);
			
		EndIf;
		// End DiscountCards
		
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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseCustomerOrderStates" Then
		
		If Not ConstantsSet.UseCustomerOrderStates Then
			
			If Not ValueIsFilled(ConstantsSet.CustomerOrdersInProgressStatus)
				OR ValueIsFilled(ConstantsSet.CustomerOrdersCompletedStatus) Then
				
				UpdateCustomerOrderStatesOnChange();
				
			EndIf;
		
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UseCustomerOrderStates" Then
		
		ThisForm.ConstantsSet.UseCustomerOrderStates = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.CustomerOrdersInProgressStatus" Then
		
		ThisForm.ConstantsSet.CustomerOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.CustomerOrdersCompletedStatus" Then
		
		ThisForm.ConstantsSet.CustomerOrdersCompletedStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseDiscountsMarkups" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseDiscountsMarkups = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionTransferGoodsOnCommission" Then
		
		ThisForm.ConstantsSet.FunctionalOptionTransferGoodsOnCommission = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionReceiveGoodsOnCommission" Then
		
		ThisForm.ConstantsSet.FunctionalOptionReceiveGoodsOnCommission = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionAccountingRetail" Then
		
		ThisForm.ConstantsSet.FunctionalOptionAccountingRetail = CurrentValue;
		
	// DiscountCards
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseDiscountCards" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseDiscountCards = CurrentValue;
		
	// End
	// DiscountCards AutomaticDiscounts
	ElsIf AttributePathToData = "ConstantsSet.FunctionalOptionUseAutomaticDiscountsMarkups" Then
		
		ThisForm.ConstantsSet.FunctionalOptionUseAutomaticDiscountsMarkups = CurrentValue;
		
	// End AutomaticDiscounts
	EndIf;
	
EndProcedure // ReturnFormAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Check the possibility to disable the UseCustomerOrderStates option.
//
&AtServer
Function CancellationUncheckUseCustomerOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CustomerOrder.Ref,
	|	CustomerOrder.OperationKind AS OperationKind
	|FROM
	|	Document.CustomerOrder AS CustomerOrder
	|WHERE
	|	(CustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR CustomerOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT CustomerOrder.Closed)
	|				AND (CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForSale)
	|					OR CustomerOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.OrderForProcessing)))
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	JobOrder.Ref,
	|	JobOrder.OperationKind
	|FROM
	|	Document.CustomerOrder AS JobOrder
	|WHERE
	|	(JobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR JobOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT JobOrder.Closed)
	|				AND JobOrder.OperationKind = VALUE(Enum.OperationKindsCustomerOrder.JobOrder))";
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr(
					"en = 'There are documents %PresentationDocumentTypes% in the base in a state with the status ""Open"" and/or ""Executed (not closed)""!
					|Disabling the option is prohibited!
					|Note:
					|If there are documents in the state with
					|the status ""Open"", set them to state with the status ""In progress""
					|or ""Executed (closed)"" If there are documents in the state
					|with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".'"
				);
		PresentationDocumentTypes = "";
		Selection = Result.Select();
		While Selection.Next() Do
			If Not IsBlankString(PresentationDocumentTypes) Then
				PresentationDocumentTypes = PresentationDocumentTypes + " and ";
			EndIf;
			If Selection.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder Then
				PresentationDocumentTypes = PresentationDocumentTypes + """Job-order""";
			Else
				PresentationDocumentTypes = PresentationDocumentTypes + """Customer order""";
			EndIf;
		EndDo;
		
		ErrorText = StrReplace(ErrorText, "%PresentationDocumentTypes%", PresentationDocumentTypes);
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckUseCustomerOrderStates()

// Check the possibility to disable the UseDiscountsMarkups option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseDiscountsMarkups()
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	SelectionMarkupAndDiscountKinds = Catalogs.MarkupAndDiscountKinds.Select();
	While SelectionMarkupAndDiscountKinds.Next() Do
		
		RefArray = New Array;
		RefArray.Add(SelectionMarkupAndDiscountKinds.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			
			ErrorText = NStr("en = 'Discounts and markups kinds are used in the base! Disabling the option is prohibited!'");
			Break;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	ArrayOfDocuments = New Array;
	ArrayOfDocuments.Add("Document.AcceptanceCertificate.WorksAndServices");
	ArrayOfDocuments.Add("Document.CustomerOrder.Inventory");
	ArrayOfDocuments.Add("Document.CustomerOrder.Works");
	ArrayOfDocuments.Add("Document.ProcessingReport.Products");
	ArrayOfDocuments.Add("Document.RetailReport.Inventory");
	ArrayOfDocuments.Add("Document.CustomerInvoice.Inventory");
	ArrayOfDocuments.Add("Document.InvoiceForPayment.Inventory");
	ArrayOfDocuments.Add("Document.ReceiptCR.Inventory");
	ArrayOfDocuments.Add("Document.ReceiptCRReturn.Inventory");
	
	QueryPattern = "SELECT TOP 1 CWT_Of document.Ref FROM &DocumentTabularSection AS CWT_Of document WHERE CWT_Of document.DiscountMarkupPercent <> 0";
	
	Query = New Query;
	
	For Each ArrayElement IN ArrayOfDocuments Do
		
		If Not IsBlankString(Query.Text) Then
			
			Query.Text = Query.Text + Chars.LF + "UNION ALL" + Chars.LF;
			
		EndIf;
		
		Query.Text = Query.Text + StrReplace(QueryPattern, "&DocumentTabularSection", ArrayElement);
		
	EndDo;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'Discounts and markups are used in the documents! Disabling the option is prohibited!'");
		
	EndIf;
	
	// DiscountCards
	If GetFunctionalOption("UseDiscountCards") Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en = 'Option ""Use discount cards"" is enabled! The flag removal is prohibited!'");
		
	EndIf;
	// End DiscountCards
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseDiscountsMarkups()

// Check the possibility to disable the TransferOfProductsOnCommission option.
//
&AtServer
Function CancellationUncheckFunctionalOptionTransferGoodsOnCommission()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryTransferred.Company
		|FROM
		|	AccumulationRegister.InventoryTransferred AS InventoryTransferred
		|WHERE
		|	InventoryTransferred.ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.TransferToAgent)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Accumulation register ""Transferred inventory"" contains information about the transfer on the commission! The flag removal is prohibited!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionTransferGoodsOnCommission()

// Check the possibility to disable the ReceiveProductsOnCommission option.
//
&AtServer
Function CancellationUncheckFunctionalOptionReceiveGoodsOnCommission()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryReceived.Company
		|FROM
		|	AccumulationRegister.InventoryReceived AS InventoryReceived
		|WHERE
		|	InventoryReceived.ReceptionTransmissionType = VALUE(Enum.ProductsReceiptTransferTypes.ReceiptFromPrincipal)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Accumulation register ""Received inventory"" contains information about the reception on a commission! The flag removal is prohibited!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionReceiveGoodsOnCommission()

// Check the possibility to disable the RetailAccounting option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingRetail()
	
	ErrorText = "";
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	SUM(ISNULL(AccumulationRegisters.RecordersCount, 0)) AS RecordersCount
	|FROM
	|	(SELECT
	|		COUNT(AccumulationRegister.Recorder) AS RecordersCount
	|	FROM
	|		AccumulationRegister.ProductRelease AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.IncomeAndExpenses AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.Inventory AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.CashInCashRegisters AS AccumulationRegister
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.RetailAmountAccounting AS AccumulationRegister
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(Catalog.Ref)
	|	FROM
	|		Catalog.StructuralUnits AS Catalog
	|	WHERE
	|		(Catalog.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)
	|				OR Catalog.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.RetailAccrualAccounting))) AS AccumulationRegisters";
	
	QuerySelection = Query.Execute().Select();
	
	If QuerySelection.Next()
		AND QuerySelection.RecordersCount > 0 Then
		
		ErrorText = NStr("en = 'In the base there are register records or objects related to the accounting retail operations! The flag removal is prohibited!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionAccountingRetail()

#Region AutomaticDiscounts

// Check on the possibility to disable the UseAutomaticDiscountsMarkups option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseAutomaticDiscountsMarkups()
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	SelectionAutomaticDiscounts = Catalogs.AutomaticDiscounts.Select();
	While SelectionAutomaticDiscounts.Next() Do
		
		RefArray = New Array;
		RefArray.Add(SelectionAutomaticDiscounts.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			
			ErrorText = NStr("en = 'Automatic discounts and markups kinds are used in the base! Disabling the option is prohibited!'");
			Break;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	ArrayOfDocuments = New Array;
	ArrayOfDocuments.Add("Document.AcceptanceCertificate.WorksAndServices");
	ArrayOfDocuments.Add("Document.CustomerOrder.Inventory");
	ArrayOfDocuments.Add("Document.CustomerOrder.Works");
	ArrayOfDocuments.Add("Document.RetailReport.Inventory");
	ArrayOfDocuments.Add("Document.CustomerInvoice.Inventory");
	ArrayOfDocuments.Add("Document.InvoiceForPayment.Inventory");
	ArrayOfDocuments.Add("Document.ReceiptCR.Inventory");
	ArrayOfDocuments.Add("Document.ReceiptCRReturn.Inventory");
	ArrayOfDocuments.Add("Document.ProcessingReport.Products");
	
	QueryPattern = "SELECT TOP 1 CWT_Of document.Ref FROM &DocumentTabularSection AS CWT_Of document WHERE CWT_Of document.AutomaticDiscountsPercent <> 0";
	
	Query = New Query;
	
	For Each ArrayElement IN ArrayOfDocuments Do
		
		If Not IsBlankString(Query.Text) Then
			
			Query.Text = Query.Text + Chars.LF + "UNION ALL" + Chars.LF;
			
		EndIf;
		
		Query.Text = Query.Text + StrReplace(QueryPattern, "&DocumentTabularSection", ArrayElement);
		
	EndDo;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + NStr("en = 'Automatic discounts and markups are used in the documents! Disabling the option is prohibited!'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseDiscountsMarkups()

#EndRegion

#Region DiscountCards

// Check on the possibility to uncheck the UseDiscountCards option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseDiscountCards()
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	SelectionDiscountCards = Catalogs.DiscountCards.Select();
	While SelectionDiscountCards.Next() Do
		
		RefArray = New Array;
		RefArray.Add(SelectionDiscountCards.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			
			ErrorText = NStr("en = 'Discount cards are used in the base! Disabling the option is prohibited!'");
			Break;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ErrorText;
	
EndFunction // CancellationUncheckFunctionalOptionUseDiscountsMarkups()

#EndRegion

// Procedure updates the parameters of the customer order status.
//
&AtServerNoContext
Procedure UpdateCustomerOrderStatesOnChange()
	
	InProcessStatus = Constants.CustomerOrdersInProgressStatus.Get();
	CompletedStatus = Constants.CustomerOrdersCompletedStatus.Get();
	
	If Not ValueIsFilled(InProcessStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	CustomerOrderStates.Ref AS State
		|FROM
		|	Catalog.CustomerOrderStates AS CustomerOrderStates
		|WHERE
		|	CustomerOrderStates.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.CustomerOrdersInProgressStatus.Set(Selection.State);
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(CompletedStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	CustomerOrderStates.Ref AS State
		|FROM
		|	Catalog.CustomerOrderStates AS CustomerOrderStates
		|WHERE
		|	CustomerOrderStates.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.CustomerOrdersCompletedStatus.Set(Selection.State);
		EndDo;
	EndIf;
	
EndProcedure // UpdateCustomerOrderStatesOnChange()

// Initialization of checking the possibility to disable the CurrencyTransactionsAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are documents Customer order or Job order with the status which differs from Executed, it is not allowed to remove the flag.
	If AttributePathToData = "ConstantsSet.UseCustomerOrderStates" Then
		
		If Constants.UseCustomerOrderStates.Get() <> ConstantsSet.UseCustomerOrderStates
			AND (NOT ConstantsSet.UseCustomerOrderStates) Then
			
			ErrorText = CancellationUncheckUseCustomerOrderStates();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the CustomerOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.CustomerOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseCustomerOrderStates
			AND Not ValueIsFilled(ConstantsSet.CustomerOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several customer orders states"" flag is cleared, but the ""In work"" customer order state parameter is not filled!'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.CustomerOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the CustomerOrdersCompletedStatus constant
	If AttributePathToData = "ConstantsSet.CustomerOrdersCompletedStatus" Then
		
		If Not ConstantsSet.UseCustomerOrderStates
			AND Not ValueIsFilled(ConstantsSet.CustomerOrdersCompletedStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several customer orders states"" flag is cleared, but the ""Executed"" customer order state parameter is not filled!'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.CustomerOrdersCompletedStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// If there are any references to discounts kinds in the documents, it is not allowed to remove the FunctionalOptionUseDiscountsMarkups flag
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseDiscountsMarkups" Then
	
		If Constants.FunctionalOptionUseDiscountsMarkups.Get() <> ConstantsSet.FunctionalOptionUseDiscountsMarkups 
			AND (NOT ConstantsSet.FunctionalOptionUseDiscountsMarkups) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseDiscountsMarkups();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any "Transferred inventory" register records, it is not allowed to remove the FunctionalOptionTransferGoodsOnCommission flag
	If AttributePathToData = "ConstantsSet.FunctionalOptionTransferGoodsOnCommission" Then
		
		If Constants.FunctionalOptionTransferGoodsOnCommission.Get() <> ConstantsSet.FunctionalOptionTransferGoodsOnCommission 
			AND (NOT ConstantsSet.FunctionalOptionTransferGoodsOnCommission) Then
			
			ErrorText = CancellationUncheckFunctionalOptionTransferGoodsOnCommission();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any "Received inventory" register records, it is not allowed to remove the FunctionalOptionReceiveGoodsOnCommission flag	
	If AttributePathToData = "ConstantsSet.FunctionalOptionReceiveGoodsOnCommission" Then
		
		If Constants.FunctionalOptionReceiveGoodsOnCommission.Get() <> ConstantsSet.FunctionalOptionReceiveGoodsOnCommission 
			AND (NOT ConstantsSet.FunctionalOptionReceiveGoodsOnCommission) Then
			
			ErrorText = CancellationUncheckFunctionalOptionReceiveGoodsOnCommission();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	
	// If there are any register records, containing the retail structural unit, it is not allowed to remove the FunctionalOptionAccountingRetail flag
	If AttributePathToData = "ConstantsSet.FunctionalOptionAccountingRetail" Then
	
		If Constants.FunctionalOptionAccountingRetail.Get() <> ConstantsSet.FunctionalOptionAccountingRetail
			AND (NOT ConstantsSet.FunctionalOptionAccountingRetail) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingRetail();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// DiscountCards
	// If there are any references to the automatic discounts kinds in the documents, it is not allowed to remove the FunctionalOptionUseDiscountCards flag
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseDiscountCards" Then
	
		If Constants.FunctionalOptionUseDiscountCards.Get() <> ConstantsSet.FunctionalOptionUseDiscountCards 
			AND (NOT ConstantsSet.FunctionalOptionUseDiscountCards) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseDiscountCards();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	// End DiscountCards
	
	// AutomaticDiscounts
	// If there are any references to the automatic discounts kinds in the documents, it is not allowed to remove the FunctionalOptionUseAutomaticDiscountsMarkups flag
	If AttributePathToData = "ConstantsSet.FunctionalOptionUseAutomaticDiscountsMarkups" Then
	
		If Constants.FunctionalOptionUseAutomaticDiscountsMarkups.Get() <> ConstantsSet.FunctionalOptionUseAutomaticDiscountsMarkups 
			AND (NOT ConstantsSet.FunctionalOptionUseAutomaticDiscountsMarkups) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseAutomaticDiscountsMarkups();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	// End AutomaticDiscounts
	
EndFunction // CheckAbilityToChangeAttributeValue()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure // UpdateSystemParameters()

// Procedure - command handler CatalogCashRegisters.
//
&AtClient
Procedure CatalogCashRegisters(Command)
	
	OpenForm("Catalog.CashRegisters.ListForm");
	
EndProcedure // CatalogCashRegisters()

// Procedure - command handler CatalogPOSTerminals.
//
&AtClient
Procedure CatalogPOSTerminals(Command)
	
	OpenForm("Catalog.POSTerminals.ListForm");
	
EndProcedure // CatalogPOSTerminals()

// Procedure - command handler CatalogCustomerOrderStates.
//
&AtClient
Procedure CatalogCustomerOrderStates(Command)
	
	OpenForm("Catalog.CustomerOrderStates.ListForm");
	
EndProcedure // CatalogCustomerOrderStates()

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
	
	// Additionally
	CommonUseClientServer.SetFormItemProperty(Items, "SettingsUseReceptionForCommission", "Enabled", ConstantsSet.FunctionalOptionUseBatches);
	
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
	
	If EventName = "Record_ConstantsSet" Then
		
		If Source = "FunctionalOptionUseBatches" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "SettingsUseReceptionForCommission", "Enabled", Parameter.Value);
			
		EndIf;
		
	EndIf;
	
EndProcedure // NotificationProcessing()

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose()
	
	RefreshApplicationInterface();
	
EndProcedure // OnClose()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnChange of the FunctionalOptionAccountingRetail field.
//
&AtClient
Procedure FunctionalOptionAccountingRetailOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingRetailOnChange()

// Procedure - event handler OnChange of the ArchiveCRReceiptsOnCloseCashCRSession field.
//
&AtClient
Procedure ArchiveCRReceiptsOnCloseCashCRSessionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // ArchiveCRReceiptsOnCloseCashCRSessionOnChange()

// Procedure - event handler OnChange of the DeleteUnissuedReceiptsOnCloseCashCRSession field.
//
&AtClient
Procedure DeleteUnpinnedChecksOnCloseCashRegisterShiftsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // DeleteUnissuedReceiptsOnCloseCashCRSession()

// Procedure - event handler OnChange of the ControlBalancesDuringCreationCRReceipts field.
//
&AtClient
Procedure ControlBalancesDuringCreationCRReceiptsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // ControlBalancesDuringCreationCRReceiptsOnChange()

// Procedure - event handler OnChange of the EnterInformationForDeclarationsOnAlcoholicProducts field.
//
&AtClient
Procedure EnterInformationForDeclarationsOnAlcoholicProductsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // EnterInformationForDeclarationsOnAlcoholicProductsOnChange()

// Procedure - event handler OnChange of the UseCustomerOrderStates field.
//
&AtClient
Procedure UseCustomerOrderStatesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // UseCustomerOrderStatesOnChange()

// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // InProcessStatusOnChange()

// Procedure - event handler OnChange of the CompletedStatus field.
// 
&AtClient
Procedure CompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // CompletedStatusOnChange()

// Procedure - event handler OnChange of the FunctionalOptionTransferGoodsOnCommission field
//
&AtClient
Procedure FunctionalOptionTransferGoodsOnCommissionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionTransferGoodsOnCommissionOnChange()

// Procedure - event handler OnChange of the FunctionalOptionReceiveGoodsOnCommission field.
//
&AtClient
Procedure FunctionalOptionReceiveGoodsOnCommissionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionReceiveGoodsOnCommissionOnChange()

// Procedure - event handler OnChange of the FunctionalOptionUseDiscountsMarkups field.
//
&AtClient
Procedure FunctionalOptionUseDiscountsMarkupsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseDiscountsMarkupsOnChange()

// Procedure - event handler OnChange of the FunctionalOptionAccountingByProjects field.
//
&AtClient
Procedure FunctionalOptionAccountingByProjectsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionAccountingByProjectsOnChange()

// Procedure - event handler OnChange of the CustomerPaymentDueDate field.
&AtClient
Procedure CustomerPaymentDueDateOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // CustomerPaymentDueDateOnChange()

#Region DiscountCards

// Procedure - event handler OnChange of the FunctionalOptionUseDiscountCards field.
//
&AtClient
Procedure FunctionalOptionFunctionalOptionUseDiscountCardsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure // FunctionalOptionUseDiscountCardsOnChange()

#EndRegion