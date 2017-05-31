// Jack 29.05.2017
//Function GetItemsUnitsOfMeasureValueList(Item) Export 

//	ValueList = New ValueList;
//	
//	If ValueIsNotFilled(Item) Then
//		Return ValueList;
//	EndIf;	
//	
//	Query = New Query;
//	Query.Text = "SELECT
//	             |	ItemsUnitsOfMeasure.UnitOfMeasure,
//	             |	ItemsUnitsOfMeasure.Quantity,
//	             |	PRESENTATION(ItemsUnitsOfMeasure.UnitOfMeasure),
//	             |	PRESENTATION(ItemsUnitsOfMeasure.Ref.BaseUnitOfMeasure)
//	             |FROM
//	             |	Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasure
//	             |WHERE
//	             |	ItemsUnitsOfMeasure.Ref = &Item
//	             |
//	             |ORDER BY
//	             |	ItemsUnitsOfMeasure.LineNumber";
//	
//	Query.SetParameter("Item", Item);
//	
//	Selection = Query.Execute().Select();
//	
//	While Selection.Next() Do
//		If ValueList.FindByValue(Selection.UnitOfMeasure) = Undefined Then
//			ValueList.Add(Selection.UnitOfMeasure,"" + Selection.UnitOfMeasurePresentation + " ("+Selection.Quantity+" "+Selection.BaseUnitOfMeasurePresentation+")");
//		EndIf;	
//	EndDo;
//	
//	Return ValueList;
//	
//EndFunction // GetItemsUnitsOfMeasureValueList()

// Object - is an object if called from managed forms
// Object - is an ordinary Form if called from ordinary form which may used as object+form

// Jack 29.05.2017 
//Function Server_PickUpRegularChoiceProcessing(ChoiceValue, Object, Form, AlwaysAddNewRow = False) Export 
//	
//	If Not ObjectsExtensionsAtServer.IsDocumentTabularPart(ChoiceValue.TabularPartName, Object.Metadata()) Then
//		Return Undefined;
//	EndIf;
//	
//	TabularPart = Object[ChoiceValue.TabularPartName];
//	
//	SearchStructure = New Structure;
//	SearchStructure.Insert("Item", ChoiceValue.Item);
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Price", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		SearchStructure.Insert("Price", ChoiceValue.Price);
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("InitialPrice", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		SearchStructure.Insert("InitialPrice", ChoiceValue.InitialPrice);
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Discount", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		SearchStructure.Insert("Discount", ChoiceValue.Discount);
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("PricePromotion", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		SearchStructure.Insert("PricePromotion", ChoiceValue.PricePromotion);
//	EndIf;
//	
//	If ChoiceValue.Property("VATRate") AND 
//		ValueIsFilled(ChoiceValue.VATRate) AND
//		ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("VATRate", Object.Metadata(), ChoiceValue.TabularPartName) AND 
//		(ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesQuota", Object.Metadata(), ChoiceValue.TabularPartName)
//		OR ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesInvoice", Object.Metadata(), ChoiceValue.TabularPartName) 
//		OR ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("PurchaseQuota", Object.Metadata(), ChoiceValue.TabularPartName)
//		OR ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesRetailQuota", Object.Metadata(), ChoiceValue.TabularPartName))Then
//		SearchStructure.Insert("VATRate", ChoiceValue.VATRate);
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Warehouse", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		SearchStructure.Insert("Warehouse", ChoiceValue.Warehouse);
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesQuota", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		If ChoiceValue.Property("SalesQuota") Then
//			SearchStructure.Insert("SalesQuota", ?(ChoiceValue.SalesQuota=Undefined,Documents.SalesQuota.EmptyRef(),ChoiceValue.SalesQuota));
//		EndIf;	
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesRetailQuota", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		If ChoiceValue.Property("SalesQuota") Then
//			SearchStructure.Insert("SalesRetailQuota", ?(ChoiceValue.SalesQuota=Undefined,Documents.SalesRetailQuota.EmptyRef(),ChoiceValue.SalesQuota));
//		EndIf;
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesInvoice", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		If ChoiceValue.Property("SalesInvoice") Then
//			SearchStructure.Insert("SalesInvoice", ?(ChoiceValue.SalesInvoice=Undefined,Documents.SalesInvoice.EmptyRef(),ChoiceValue.SalesInvoice));
//		EndIf;	
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("PurchaseQuota", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		If ChoiceValue.Property("PurchaseQuota") Then
//			SearchStructure.Insert("PurchaseQuota", ChoiceValue.PurchaseQuota);
//		EndIf;	
//	EndIf;
//	
//	If AlwaysAddNewRow Then
//		ItemsLinesRow = Undefined;
//	Else	
//		ItemsLinesRow = TablesProcessingAtClientAtServer.FindTabularPartRow(TabularPart, SearchStructure);
//	EndIf;	
//	
//	If ItemsLinesRow = Undefined Then
//		
//		ItemsLinesRow = TabularPart.Add();
//		
//		ItemsLinesRow.Item          = ChoiceValue.Item;
//		ItemsLinesRow.UnitOfMeasure = ChoiceValue.UnitOfMeasure;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Warehouse", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			ItemsLinesRow.Warehouse     = ChoiceValue.Warehouse;
//		EndIf;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Price", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			ItemsLinesRow.Price         = ChoiceValue.Price;
//		EndIf;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("InitialPrice", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			ItemsLinesRow.InitialPrice         = ChoiceValue.InitialPrice;
//		EndIf;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("PricePromotion", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			ItemsLinesRow.PricePromotion         = ChoiceValue.PricePromotion;
//		EndIf;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Discount", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			ItemsLinesRow.Discount         = ChoiceValue.Discount;
//		EndIf;

//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesInvoice", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("SalesInvoice") Then
//				ItemsLinesRow.SalesInvoice     = ?(ChoiceValue.SalesInvoice=Undefined,Documents.SalesInvoice.EmptyRef(),ChoiceValue.SalesInvoice);			
//			EndIf;	
//		EndIf;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesQuota", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("SalesQuota") Then
//				ItemsLinesRow.SalesQuota     = ?(ChoiceValue.SalesQuota=Undefined,Documents.SalesQuota.EmptyRef(),ChoiceValue.SalesQuota);			
//			EndIf;	
//		EndIf;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesRetailQuota", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("SalesQuota") Then
//				ItemsLinesRow.SalesRetailQuota     = ?(ChoiceValue.SalesQuota=Undefined,Documents.SalesRetailQuota.EmptyRef(),ChoiceValue.SalesQuota);			
//			EndIf;	
//		EndIf;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("PurchaseQuota", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("PurchaseQuota") Then
//				ItemsLinesRow.PurchaseQuota     = ChoiceValue.PurchaseQuota;
//			EndIf;	
//		EndIf;
//		
//		If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("VATRate", Object.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("VATRate") 
//				AND ValueIsFilled(ChoiceValue.VATRate) 
//				AND (ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesQuota", Object.Metadata(), ChoiceValue.TabularPartName)
//				OR ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("PurchaseQuota", Object.Metadata(), ChoiceValue.TabularPartName)
//				OR ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesInvoice", Object.Metadata(), ChoiceValue.TabularPartName)
//				OR ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("SalesRetailQuota", Object.Metadata(), ChoiceValue.TabularPartName)) Then
//				ItemsLinesRow.VATRate      = ChoiceValue.VATRate;
//			ElsIf ObjectsExtensionsAtServer.IsDocumentAttribute("Customer", Object.Metadata()) Then
//				ItemsLinesRow.VATRate      = TaxesAtClientAtServer.GetVATRate(Object.Company, Object.Customer.AccountingGroup, ItemsLinesRow.Item.AccountingGroup);
//			ElsIf ObjectsExtensionsAtServer.IsDocumentAttribute("Supplier", Object.Metadata()) Then
//				ItemsLinesRow.VATRate      = TaxesAtClientAtServer.GetVATRate(Object.Company, Object.Supplier.AccountingGroup, ItemsLinesRow.Item.AccountingGroup);
//			EndIf;
//		EndIf;
//		
//	EndIf;
//	
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Quantity", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		ItemsLinesRow.Quantity      = ItemsLinesRow.Quantity + ChoiceValue.Quantity;
//	EndIf;
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Amount", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		
//		If ValueIsFilled(ChoiceValue.Amount) Then
//			ItemsLinesRow.Amount        = ItemsLinesRow.Amount + ChoiceValue.Amount;
//		Else	
//			ItemsLinesRow.Amount        = DocumentsTabularPartsProcessingAtClientAtServer.GetItemsLinesRowAmount(ItemsLinesRow.Price, ItemsLinesRow.Quantity);
//		EndIf;	
//		
//	EndIf;
//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("VAT", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		If ValueIsFilled(ChoiceValue.VAT) Then
//			ItemsLinesRow.VAT        = ItemsLinesRow.VAT + ChoiceValue.VAT;
//		Else	
//			ItemsLinesRow.VAT    = DocumentsTabularPartsProcessingAtClientAtServer.GetItemsLinesRowVATAmount(ItemsLinesRow.Amount, ItemsLinesRow.VATRate, Object.AmountType);
//		EndIf;	
//	EndIf;
//	
//	IsManagedForm = (TypeOf(Form) = Type("ManagedForm"));
//	If IsManagedForm Then
//		ColumnsSet = Form.Items[ChoiceValue.TabularPartName].ChildItems;
//		CurrentColumnNamePrefix = ChoiceValue.TabularPartName;
//		Form.Items[ChoiceValue.TabularPartName].CurrentRow = Object[ChoiceValue.TabularPartName].IndexOf(ItemsLinesRow);
//	Else	
//		ColumnsSet = Form.Controls[ChoiceValue.TabularPartName].Columns;
//		CurrentColumnNamePrefix = "";
//		Form.Controls[ChoiceValue.TabularPartName].CurrentRow    = ItemsLinesRow;
//	EndIf;	

//	If ObjectsExtensionsAtServer.IsDocumentTabularPartAttribute("Quantity", Object.Metadata(), ChoiceValue.TabularPartName) Then
//		If IsManagedForm Then
//			Form.Items[ChoiceValue.TabularPartName].CurrentItem = ColumnsSet[CurrentColumnNamePrefix+"Quantity"];
//		Else
//			Form.Controls[ChoiceValue.TabularPartName].CurrentColumn = ColumnsSet[CurrentColumnNamePrefix+"Quantity"];
//		EndIf;	
//	Else
//		If IsManagedForm Then
//			Form.Items[ChoiceValue.TabularPartName].CurrentItem = ColumnsSet[CurrentColumnNamePrefix+"Item"];
//		Else
//			Form.Controls[ChoiceValue.TabularPartName].CurrentColumn = ColumnsSet[CurrentColumnNamePrefix+"Item"];
//		EndIf;	
//	EndIf;
//	
//	Return ItemsLinesRow;
//	
//EndFunction // Server_PickUpRegularChoiceProcessing()

Procedure AllowAccountsExtDimensions(Account, ExtDimensionName = "ExtDimension", Controls, OrdinaryForm = True) Export
	
	MaxExtraDimension = Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount;
	
	For Counter = 1 To MaxExtraDimension Do
		
		// get label control
		LabelControl = Controls.Find("Label" + ExtDimensionName + Counter);
		
		If Not ValueIsFilled(Account) Or Counter > Account.ExtDimensionTypes.Count() Then
			
			Controls[ExtDimensionName + Counter].ReadOnly = True;
			
			If OrdinaryForm Then
				If LabelControl <> Undefined Then
					LabelControl.Value = NStr("en = 'Extra dimension '; pl = 'Analityka '") + Counter + ":";
					LabelControl.Enabled = False;
				EndIf;
			Else
				Controls[ExtDimensionName + Counter].Title = NStr("en = 'Extra dimension '; pl = 'Analityka '") + Counter;
			EndIf;
			
		Else
			Controls[ExtDimensionName + Counter].ReadOnly = False; 
			
			If OrdinaryForm Then
				If LabelControl <> Undefined Then
					ExtDimensionType = Account.ExtDimensionTypes[Counter-1].ExtDimensionType;
					LabelControl.Value = String(ExtDimensionType) + ":";
					LabelControl.Enabled = True;
				EndIf;
			Else
				Controls[ExtDimensionName + Counter].Title =  String(Account.ExtDimensionTypes[Counter-1].ExtDimensionType);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure	

Procedure SetWeightAndVolumeColumnsHeaderText(TableBox, WeightColumnName = "Weight", VolumeColumnName = "Volume", GrossWeightColumnName = "") Export
	
	TableBox.Columns[WeightColumnName].HeaderText = TableBox.Columns[WeightColumnName].HeaderText + " (" + Constants.WeightUnitOfMeasure.Get() + ")";
	TableBox.Columns[VolumeColumnName].HeaderText = TableBox.Columns[VolumeColumnName].HeaderText + " (" + Constants.VolumeUnitOfMeasure.Get() + ")";
	
	If NOT IsBlankString(GrossWeightColumnName) Then
		TableBox.Columns[GrossWeightColumnName].HeaderText = TableBox.Columns[GrossWeightColumnName].HeaderText + " (" + Constants.WeightUnitOfMeasure.Get() + ")";
	EndIf;	
	
EndProcedure

Procedure SetWeightAndVolumeColumnsHeaderTextManaged(TableBox, WeightColumnName = "Weight", VolumeColumnName = "Volume", GrossWeightColumnName = "") Export
	
	TableBox.ChildItems[TableBox.Name + WeightColumnName].Title = Nstr("en='Weight net';pl='Waga netto';ru='Вес нетто'") + " (" + Constants.WeightUnitOfMeasure.Get() + ")";
	TableBox.ChildItems[TableBox.Name + VolumeColumnName].Title = Nstr("en='Volume';pl='Objętość';ru='Объем'") + " (" + Constants.VolumeUnitOfMeasure.Get() + ")";
	
	If NOT IsBlankString(GrossWeightColumnName) Then
		TableBox.ChildItems[TableBox.Name + GrossWeightColumnName].Title = Nstr("en='Weight gross';pl='Waga brutto';ru='Вес брутто'") + " (" + Constants.WeightUnitOfMeasure.Get() + ")";
	EndIf;	
	
EndProcedure
