
#Region FormEventsHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.DocumentRef = Undefined Then
		Raise NStr("en='Report can be opened only from documents.'");
	EndIf;
	
	DocumentRef = Parameters.DocumentRef;
	
	DiscountsAreCalculated = DocumentRef.DiscountsAreCalculated;
	
	Generate();
	
EndProcedure

// Procedure - OnOpen form event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	If TypeOf(FormOwner) = Type("ManagedForm") Then
		If FormOwner.Modified Then
			Items.WarningDecoration.Visible = True;
		Else
			Items.WarningDecoration.Visible = False;
		EndIf;
	EndIf;
	
	If Not DiscountsAreCalculated Then
		If Items.WarningDecoration.Visible Then
			Items.WarningDecoration.Title = Items.WarningDecoration.Title + " IN the document discounts and markups are not calculated!";
		Else
			Items.WarningDecoration.Visible = True;
			Items.WarningDecoration.Title = "In the document discounts and markups are not calculated!";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	Generate();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure RecursiveDiscountsBypass(DiscountsTree, DiscountsArray)
	
	For Each TreeRow IN DiscountsTree.Rows Do
		
		If TreeRow.IsFolder Then
			
			RecursiveDiscountsBypass(TreeRow, DiscountsArray);
			
		Else
			
			DiscountsArray.Add(TreeRow);
		
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function GetAutomaticDiscountCalculationParametersStructureServer(CustomerInvoiceRef)

	OrderParametersStructure = New Structure("SalesByOrders, SalesExceedingOrder", False, False);
	
	Query = New Query;
	If TypeOf(CustomerInvoiceRef) = Type("DocumentRef.AcceptanceCertificate") Then
		Query.Text = 
			"SELECT
			|	AcceptanceCertificateWorksAndServices.CustomerOrder AS Order
			|FROM
			|	Document.AcceptanceCertificate.WorksAndServices AS AcceptanceCertificateWorksAndServices
			|WHERE
			|	AcceptanceCertificateWorksAndServices.Ref = &Ref
			|
			|GROUP BY
			|	AcceptanceCertificateWorksAndServices.CustomerOrder";
			
	ElsIf TypeOf(CustomerInvoiceRef) = Type("DocumentRef.ProcessingReport") Then
		Query.Text = 
			"SELECT
			|	ProcessingReport.CustomerOrder AS Order
			|FROM
			|	Document.ProcessingReport AS ProcessingReport
			|WHERE
			|	ProcessingReport.Ref = &Ref
			|
			|GROUP BY
			|	ProcessingReport.CustomerOrder";
	Else
		Query.Text = 
			"SELECT
			|	CustomerInvoiceInventory.Order AS Order
			|FROM
			|	Document.CustomerInvoice.Inventory AS CustomerInvoiceInventory
			|WHERE
			|	CustomerInvoiceInventory.Ref = &Ref
			|
			|GROUP BY
			|	CustomerInvoiceInventory.Order";
	EndIf;
	
	Query.SetParameter("Ref", CustomerInvoiceRef);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		If ValueIsFilled(Selection.Order) Then
			OrderParametersStructure.SalesByOrders = True;
		Else
			OrderParametersStructure.SalesExceedingOrder = True;
		EndIf;
	EndDo;
	
	Return OrderParametersStructure;
	
EndFunction // ThereAreOrdersInTS()

&AtServer
Procedure Generate()
	
	SpreadsheetDocument.Clear();
	
	DocumentObject = DocumentRef.GetObject();
	
	Template = Reports.DiscountsAppliedInDocument.GetTemplate("Template");
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	If TypeOf(DocumentObject) = Type("DocumentObject.AcceptanceCertificate") Then
		TSName = "WorksAndServices";
	ElsIf TypeOf(DocumentObject) = Type("DocumentObject.ProcessingReport") Then
		TSName = "Products";
	Else
		TSName = "Inventory";
	EndIf;
	
	FixedTop = 1;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.CustomerInvoice") Then
		
		AutomaticDiscountsCalculationParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(DocumentObject.Ref);
		
		DisplayAdditionalMessage = True;
		If AutomaticDiscountsCalculationParametersStructure.SalesByOrders AND Not AutomaticDiscountsCalculationParametersStructure.SalesExceedingOrder Then
			AdditionalMessageText = "Discounts are calculated based on order data!";
		ElsIf AutomaticDiscountsCalculationParametersStructure.SalesByOrders AND AutomaticDiscountsCalculationParametersStructure.SalesExceedingOrder Then
			AdditionalMessageText = "Discounts are calculated based on order data! Strings over the order are calculated separately!";			
		Else
			DisplayAdditionalMessage = False;
		EndIf;
		If DisplayAdditionalMessage Then
			AdditionalMessageArea = Template.GetArea("RealizationOnClientRequest");
			AdditionalMessageArea.Parameters.AdditionalMessage = AdditionalMessageText;
			SpreadsheetDocument.Put(AdditionalMessageArea);
			FixedTop = 2;
		Else
			FixedTop = 1;
		EndIf;
		
	EndIf;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.AcceptanceCertificate") Then
		
		AutomaticDiscountsCalculationParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(DocumentObject.Ref);
		
		DisplayAdditionalMessage = True;
		If AutomaticDiscountsCalculationParametersStructure.SalesByOrders AND Not AutomaticDiscountsCalculationParametersStructure.SalesExceedingOrder Then
			AdditionalMessageText = "Discounts are calculated based on order data!";
		ElsIf AutomaticDiscountsCalculationParametersStructure.SalesByOrders AND AutomaticDiscountsCalculationParametersStructure.SalesExceedingOrder Then
			AdditionalMessageText = "Discounts are calculated based on order data! Strings over the order are calculated separately!";			
		Else
			DisplayAdditionalMessage = False;
		EndIf;
		If DisplayAdditionalMessage Then
			AdditionalMessageArea = Template.GetArea("RealizationOnClientRequest");
			AdditionalMessageArea.Parameters.AdditionalMessage = AdditionalMessageText;
			SpreadsheetDocument.Put(AdditionalMessageArea);
			FixedTop = 2;
		Else
			FixedTop = 1;
		EndIf;
		
	EndIf;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.ProcessingReport") Then
		
		AutomaticDiscountsCalculationParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(DocumentObject.Ref);
		
		DisplayAdditionalMessage = True;
		If AutomaticDiscountsCalculationParametersStructure.SalesByOrders AND Not AutomaticDiscountsCalculationParametersStructure.SalesExceedingOrder Then
			AdditionalMessageText = "Discounts are calculated based on order data!";
		ElsIf AutomaticDiscountsCalculationParametersStructure.SalesByOrders AND AutomaticDiscountsCalculationParametersStructure.SalesExceedingOrder Then
			AdditionalMessageText = "Discounts are calculated based on order data! Strings over the order are calculated separately!";
		Else
			DisplayAdditionalMessage = False;
		EndIf;
		If DisplayAdditionalMessage Then
			AdditionalMessageArea = Template.GetArea("RealizationOnClientRequest");
			AdditionalMessageArea.Parameters.AdditionalMessage = AdditionalMessageText;
			SpreadsheetDocument.Put(AdditionalMessageArea);
			FixedTop = 2;
		Else
			FixedTop = 1;
		EndIf;
		
	EndIf;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.InvoiceForPayment") Then
		
		DisplayAdditionalMessage = True;
		If DocumentObject.BasisDocument <> Undefined AND Not DocumentObject.BasisDocument.IsEmpty() Then
			If TypeOf(DocumentObject.BasisDocument) = Type("DocumentRef.CustomerOrder")
				OR TypeOf(DocumentObject.BasisDocument) = Type("DocumentRef.AcceptanceCertificate")
				OR TypeOf(DocumentObject.BasisDocument) = Type("DocumentRef.CustomerInvoice")
				Then
				AdditionalMessageText = "Discounts are calculated based on data of the basis document!";
			Else
				DisplayAdditionalMessage = False;
			EndIf;
		Else
			DisplayAdditionalMessage = False;
		EndIf;
		If DisplayAdditionalMessage Then
			AdditionalMessageArea = Template.GetArea("RealizationOnClientRequest");
			AdditionalMessageArea.Parameters.AdditionalMessage = AdditionalMessageText;
			SpreadsheetDocument.Put(AdditionalMessageArea);
			FixedTop = 2;
		Else
			FixedTop = 1;
		EndIf;
		
	EndIf;
	
	ProductsAndServicesCharacteristicsUsage = GetFunctionalOption("UseCharacteristics");
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(DocumentObject, ParameterStructure);
	
	DiscountsArray = New Array;
	RecursiveDiscountsBypass(AppliedDiscounts.DiscountsTree, DiscountsArray);
	
	AreaHeaderProductsAndServices              = Template.GetArea("Header|ProductsAndServices");
	AreaHeaderCharacteristic            = Template.GetArea("Header|Characteristic");
	AreaHeaderAmountAndCompleted           = Template.GetArea("Header|AmountAndCompleted");
	
	AreaStringProductsAndServices             = Template.GetArea("String|ProductsAndServices");
	AreaStringCharacteristic           = Template.GetArea("String|Characteristic");
	AreaStringAmountAndCompleted          = Template.GetArea("String|AmountAndCompleted");
	
	AreaTotalProductsAndServices              = Template.GetArea("StringTotal|ProductsAndServices");
	AreaTotalCharacteristic            = Template.GetArea("StringTotal|Characteristic");
	AreaTotalAmountAndCompleted           = Template.GetArea("StringTotal|AmountAndCompleted");
	
	AreaLegend                        = Template.GetArea("Legend|ProductsAndServices");
	
	// Report header
	SpreadsheetDocument.Put(AreaHeaderProductsAndServices);
	If ProductsAndServicesCharacteristicsUsage Then
		SpreadsheetDocument.Join(AreaHeaderCharacteristic);
	EndIf;
	SpreadsheetDocument.Join(AreaHeaderAmountAndCompleted);
	
	SpreadsheetDocument.FixedTop = FixedTop;
	
	ConditionsFulfilmentAccordance = New Map;
	
	TSNamesArray = New Array;
	DisplayTSName = False;
	If TypeOf(DocumentObject) = Type("DocumentObject.CustomerOrder") AND DocumentObject.OperationKind = Enums.OperationKindsCustomerOrder.JobOrder 
		AND DocumentObject.Works.Count() > 0 Then
		TSNamesArray.Add("Works");
		DisplayTSName = True;
	EndIf;
	TSNamesArray.Add(TSName);
	
	For Each CurrentTSName IN TSNamesArray Do
		
		If DisplayTSName AND DocumentObject[CurrentTSName].Count() > 0 Then
			If ProductsAndServicesCharacteristicsUsage Then
				AreaTSName = Template.GetArea("NameTPCharacteristics");
			Else
				AreaTSName = Template.GetArea("TSName");
			EndIf;
			AreaTSName.Parameters.TSName = "For tabular section """+CurrentTSName+"""";
			SpreadsheetDocument.Put(AreaTSName);
		EndIf;
		
		For Each ProductsRow IN DocumentObject[CurrentTSName] Do
			
			AreaStringProductsAndServices.Parameters.ProductsAndServices = ProductsRow.ProductsAndServices;
			AreaStringProductsAndServices.Parameters.LineNumber  = ProductsRow.LineNumber;
			SpreadsheetDocument.Put(AreaStringProductsAndServices);
			If ProductsAndServicesCharacteristicsUsage Then
				AreaStringCharacteristic.Parameters.Characteristic = ProductsRow.Characteristic;
				SpreadsheetDocument.Join(AreaStringCharacteristic);
			EndIf;
			AreaStringAmountAndCompleted.Parameters.Amount = ProductsRow.AutomaticDiscountAmount;
			SpreadsheetDocument.Join(AreaStringAmountAndCompleted);
			
			SpreadsheetDocument.StartRowGroup("ProductsAndServices", True);
			For Each TreeRow IN DiscountsArray Do
				
				If CurrentTSName = "Works" Then
					CurAttributeConnectionKey = "ConnectionKeyForMarkupsDiscounts";
				Else
					CurAttributeConnectionKey = "ConnectionKey";
				EndIf;
				
				// Discount conditions
				AllConditionsFulfilled = True;
				For Each RowCondition IN TreeRow.ConditionsParameters.TableConditions Do
					
					If RowCondition.RestrictionArea = Enums.DiscountMarkupRestrictionAreasVariants.AtRow Then
						FoundConditionsCheckingTableRows = TreeRow.ConditionsParameters.ConditionsByLine.ConditionsCheckingTable.Find(ProductsRow[CurAttributeConnectionKey], "ConnectionKey");
						If FoundConditionsCheckingTableRows <> Undefined Then
							ColumnName = TreeRow.ConditionsParameters.ConditionsByLine.MatchConditionTableColumnsWithConditionsCheckingTable.Get(RowCondition.AssignmentCondition);
							If ColumnName <> Undefined Then
								ConditionExecuted = FoundConditionsCheckingTableRows[ColumnName];
							EndIf;
						Else
							ConditionExecuted = False;
						EndIf;
					Else
						ConditionExecuted = RowCondition.Completed;
					EndIf;
					ConditionsFulfilmentAccordance.Insert(RowCondition.AssignmentCondition, ConditionExecuted);
					
					If Not ConditionExecuted Then
						AllConditionsFulfilled = False;
					EndIf;
					
				EndDo;
				
				// Discount amount
				If TreeRow.DataTable.Count() = 0 Then
					DiscountAmount = 0;
				Else
					FoundString = TreeRow.DataTable.Find(ProductsRow[CurAttributeConnectionKey], "ConnectionKey");
					If FoundString <> Undefined Then
						DiscountAmount = FoundString.Amount;
					Else
						DiscountAmount = 0;
					EndIf;
				EndIf;
				
				If AllConditionsFulfilled Then
					If DocumentObject.DiscountsMarkups.FindRows(New Structure("ConnectionKey, DiscountMarkup", ProductsRow[CurAttributeConnectionKey], TreeRow.DiscountMarkup)).Count() = 0 Then
						// Not valid for shared use.
						TextColor = "Gray";
						Strikeout = "Strikeout";
					Else
						// Present in document. Conditions are fullfilled.
						TextColor = "";
						Strikeout = "";
					EndIf;
				Else
					// Conditions are not fulfilled.
					TextColor = "Red";
					Strikeout = "Strikeout";
				EndIf;
				
				If ProductsAndServicesCharacteristicsUsage Then
					AreaDiscount                         = Template.GetArea("DiscountCharacteristicsPresent"+Strikeout+TextColor+"|ProductsAndServicesAndCharacteristics");
					AreaDiscountAmountAndCompleted          = Template.GetArea("DiscountCharacteristicsPresent"+Strikeout+TextColor+"|AmountAndCompleted");
				Else
					AreaDiscount                         = Template.GetArea("Discount"+Strikeout+TextColor+"|ProductsAndServices");
					AreaDiscountAmountAndCompleted          = Template.GetArea("Discount"+Strikeout+TextColor+"|AmountAndCompleted");
				EndIf;
				
				AreaDiscount.Parameters.DiscountMarkup = TreeRow.DiscountMarkup;
				SpreadsheetDocument.Put(AreaDiscount);
				
				AreaDiscountAmountAndCompleted.Parameters.Amount = DiscountAmount;
				SpreadsheetDocument.Join(AreaDiscountAmountAndCompleted);
				
				SpreadsheetDocument.StartRowGroup("Discount", True);
				
				// Discount conditions, continuation
				For Each RowCondition IN TreeRow.ConditionsParameters.TableConditions Do
					
					If ConditionsFulfilmentAccordance.Get(RowCondition.AssignmentCondition) Then
						// The condition is fullfilled.
						Strikeout = "";
					Else
						// Condition is not completed.
						Strikeout = "Strikeout";
					EndIf;
					
					If ProductsAndServicesCharacteristicsUsage Then
						AreaCondition                        = Template.GetArea("ConditionCharacteristicsPresent"+Strikeout+TextColor+"|ProductsAndServicesAndCharacteristics");
						AreaConditionAmountAndCompleted         = Template.GetArea("ConditionCharacteristicsPresent"+Strikeout+TextColor+"|AmountAndCompleted");
					Else
						AreaCondition                        = Template.GetArea("Condition"+Strikeout+TextColor+"|ProductsAndServices");
						AreaConditionAmountAndCompleted         = Template.GetArea("Condition"+Strikeout+TextColor+"|AmountAndCompleted");
					EndIf;
					
					AreaCondition.Parameters.Condition = RowCondition.AssignmentCondition;
					SpreadsheetDocument.Put(AreaCondition);
					
					SpreadsheetDocument.Join(AreaConditionAmountAndCompleted);
					
				EndDo;
				
				SpreadsheetDocument.EndRowGroup(); // Discount.
				
			EndDo;
			
			SpreadsheetDocument.EndRowGroup(); // ProductsAndServices.
			
		EndDo;
	EndDo;
	
	// Total
	SpreadsheetDocument.Put(AreaTotalProductsAndServices);
	If ProductsAndServicesCharacteristicsUsage Then
		SpreadsheetDocument.Join(AreaTotalCharacteristic);
	EndIf;
	AreaTotalAmountAndCompleted.Parameters.Amount = DocumentObject[TSName].Total("AutomaticDiscountAmount");
	SpreadsheetDocument.Join(AreaTotalAmountAndCompleted);
	
	SpreadsheetDocument.Put(AreaLegend);
	
EndProcedure

#EndRegion



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
