
// Checks whether all rows of tabular parts are unique
// based on given column names list (Structure).
Procedure ObjectTabularPartRowUniquenessValidation(Object, Val TabularPartName, Val KeyColumnNames, Cancel, Val Title = "") Export 
	
	TabularPart = Object[TabularPartName];
	
	//presentation variables used for displaying messages
	TabularPartMetadata = Object.Metadata().TabularSections[TabularPartName];
	TabularPartPresentation = TabularPartMetadata.Presentation();
	
	ColumnPresentationsString = ""; // this one will be filled in the iteration below
	ColumnNamesString = "";         // prepare a column list string ("Column1, Column2, ...") - for GroupBy function
	
	If TypeOf(KeyColumnNames) = Type("String") Then
		
		TempColumnName = KeyColumnNames;
		KeyColumnNames = New Structure();
		KeyColumnNames.Insert(TempColumnName);
		
	EndIf;	
	
	For Each ColumnKeyAndValue In KeyColumnNames Do
		
		ColumnNamesString = ColumnNamesString + StringFunctionsClientServer.AddStringSeparator(ColumnNamesString) + ColumnKeyAndValue.Key;
		ColumnPresentationsString = ColumnPresentationsString + StringFunctionsClientServer.AddStringSeparator(ColumnPresentationsString) + TabularPartMetadata.Attributes[ColumnKeyAndValue.Key].Presentation();
		
	EndDo;
	
	//create a ValueTable initially containing original tabular part
	TabularPartClone = TabularPart.Unload();
	
	//get row values (if such rows exist) which are duplicated in tabular part
	TabularPartClone.Columns.Add("RowCount"); //add a column which will count how many such row appears in tabular table
	TabularPartClone.FillValues(1, "RowCount");
	TabularPartClone.GroupBy(ColumnNamesString, "RowCount");
	
	RowsAreDuplicated = False;
	RowFilters = New Array; //Array of Structure, containing all row filters, one per duplicated rows set
	
	DuplicatedRowValues = New Array(KeyColumnNames.Count()); //this will be used to copy values of row encountered more than once
	
	// Find duplicates occurance
	For Each TabularPartCloneRow In TabularPartClone Do
		
		If TabularPartCloneRow.RowCount > 1 Then //this is a duplicated row
			
			RowsAreDuplicated = True;
			
			RowFilter = New Structure; // this will contain criteria for future searching of duplicated rows in tabular part
			
			// Retrieve values that are in a duplicated row.
			For Each KeyAndValue In KeyColumnNames Do
				RowFilter.Insert(KeyAndValue.Key, TabularPartCloneRow[KeyAndValue.Key]); //form filter for row searching
			EndDo;
			
			// Store new row filter for duplicated rows set.
			RowFilters.Add(RowFilter);
			
		EndIf;
		
	EndDo;
	
	OutMessage = NStr("en='After checking uniqueness of rows in tabular part ""';pl='Po sprawdzeniu unikalności wierszy w części tabelarycznej ""'") + TabularPartPresentation + NStr("en='"" on values of columns (';pl='"" na wartościach w kolumnach ('") + ColumnPresentationsString + NStr("en="") the following duplicates found:"";pl="") znaleziono następujące duplikaty:""");
	
	//if there are duplicated rows, find them and return appropriate message
	If RowsAreDuplicated Then
		
		For Each RowFilter in RowFilters Do
			
			DuplicatedRows = TabularPart.FindRows(RowFilter);
			OutMessage = OutMessage + Chars.LF + NStr("en='There are duplicated rows:';pl='Zduplikowane wiersze:'") + " " + DuplicatedRows[0].LineNumber;
			
			For i = 1 To DuplicatedRows.UBound() Do
				OutMessage = OutMessage + ", " + DuplicatedRows[i].LineNumber;
			EndDo;
			
		EndDo;
		
		Alerts.AddAlert(Title + " " + OutMessage,, Cancel, Object);
		
	EndIf;
	
EndProcedure //ObjectTabularPartRowUniquenessValidation()

Function GetItemsLinesRowAmount(Price, Quantity) Export 
	
	Return Price*Quantity;
	
EndFunction

Function GetItemsLinesRowVATAmount(Amount, VATRate, AmountType) Export 
	
	Return Amount/(100 + (VATRate.Percentage*?(AmountType = Enums.NetGross.Gross, 1,0)))*VATRate.Percentage;
	
EndFunction

// Jack 29.05.2017
//Function GetItemsLinesRowPrice(Amount, Quantity, OldPrice = 0) Export 
//	
//	If OldPrice = 0 And Quantity <> 0 Then
//		
//		Return Amount / Quantity;
//		
//	Else
//		
//		Return OldPrice;
//		
//	EndIf;
//	
//EndFunction

Function GetGrossAmount(Amount, VAT, AmountType) Export
	
	Return Amount + ?(AmountType = Enums.NetGross.Gross, 0, VAT);
	
EndFunction // GetGrossAmount()

Function GetNetAmount(Amount, VAT, AmountType) Export
	
	Return Amount - ?(AmountType = Enums.NetGross.Gross, VAT, 0);
	
EndFunction // GetNetAmount()

Procedure FillTabularPartAttribute(Object, TabularPartName, AttributeName, AttributeValue) Export
	
	ObjectMetadata = Object.Metadata();
	If Common.IsDocumentTabularPart(TabularPartName,ObjectMetadata) 
		AND Common.IsDocumentTabularPartAttribute(AttributeName,ObjectMetadata,TabularPartName) Then
		
		TabularPart = Object[TabularPartName];
		For Each TabularPartRow In TabularPart Do
			
			If TabularPartRow[AttributeName]<> AttributeValue Then 
				TabularPartRow[AttributeName] = AttributeValue;
			EndIf;	
			
		EndDo;	
		
	EndIf;	
	
EndProcedure	

Function TabularPartCleaning(TabularPart) Export 
	
	If TabularPart.Count() > 0 Then
		
	#If Client Then
		Answer = DoQueryBox(NStr("en='Tabular part would be cleaned up. Existing rows would be deleted. Continue?';pl='Część tabelaryczna zostanie wyczyszczona. Istniejące wiersze zostaną skasowane. Czy kontynuować?'"), QuestionDialogMode.OKCancel);
		If Answer <> DialogReturnCode.OK Then
			Return False;
		EndIf;
	#EndIf
		
		TabularPart.Clear();
		
	EndIf;
	
	Return True;
	
EndFunction

Function TabularPartCanBeFilled(TabularPart, Posted) Export 
	
	If Posted Then
		#If Client Then
			ShowMessageBox(, NStr("en='Please, clear posting of the document before filling.';pl='Odksięguj dokument przed rozpoczęciem jego wypełniania.'"));
		#EndIf
		Return False;
	EndIf;
	
	If Not TabularPartCleaning(TabularPart) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure InsertSearchStructure(SearchStructure, Name, ChoiceValue, Form)
	If TypeOf(Form) = Type("Structure") Then
		If Not Form[ChoiceValue.TabularPartName].Find(Name) = Undefined Then
			SearchStructure.Insert(Name, ChoiceValue[Name]);
		EndIf;
	ElsIf Not Form = Undefined And Common.IsDocumentTabularPartAttribute(Name, Form.Metadata(), ChoiceValue.TabularPartName) Then
		SearchStructure.Insert(Name, ChoiceValue[Name]);
	EndIf;
EndProcedure

Procedure SetAttribute(ItemsLinesRow, Name, ChoiceValue, Form, AddNumbersValue = False)
	If TypeOf(Form) = Type("Structure") Then
		If Not Form[ChoiceValue.TabularPartName].Find(Name) = Undefined Then
			If AddNumbersValue Then
				ItemsLinesRow[Name]     = ChoiceValue[Name] + ItemsLinesRow[Name];
			Else
				ItemsLinesRow[Name]     = ChoiceValue[Name];
			EndIf;
		EndIf;
	ElsIf Form = Undefined  Then
		If ItemsLinesRow.Property(Name) Then
			ItemsLinesRow[Name]     = ChoiceValue[Name];
		EndIf;
	ElsIf Common.IsDocumentTabularPartAttribute(Name, Form.Metadata(), ChoiceValue.TabularPartName) Then
		If AddNumbersValue Then
			ItemsLinesRow[Name]     = ChoiceValue[Name] + ItemsLinesRow[Name];
		Else
			ItemsLinesRow[Name]     = ChoiceValue[Name];
		EndIf;
	EndIf;
EndProcedure

// Jack 29.05.2017
//Function PickUpRegularChoiceProcessing(ChoiceValue, Val Form, AlwaysAddNewRow = False, AttributesStructure = Undefined) Export 
//	IsManagedForm = False;
//	If TypeOf(Form) = Type("ManagedForm") Then
//		If Not AttributesStructure = Undefined Then
//			If AttributesStructure["ObjectDataProcessors"].Find(ChoiceValue.TabularPartName) = Undefined Then
//				Return Undefined;
//			EndIf;
//			If AttributesStructure[ChoiceValue.TabularPartName].Find("Item") = Undefined Then
//				Return Undefined;
//			EndIf;
//		EndIf;
//		IsManagedForm = True;
//	ElsIf Not Form = Undefined And Not Common.IsDocumentTabularPart(ChoiceValue.TabularPartName, Form.Metadata()) Then
//		Return Undefined;
//	EndIf;
//	
//	If IsManagedForm Then
//		FormAttributes = Form.GetAttributes();
//		IsObject = False;
//		For Each Attribute In FormAttributes Do
//			If Attribute.Name = "Object" Then
//				IsObject = True;
//				Break;
//			EndIf;
//		EndDo;
//		If IsObject Then
//			TabularPart = Form.Object[ChoiceValue.TabularPartName];
//		Else
//			TabularPart = Form[ChoiceValue.TabularPartName];
//		EndIf;
//	Else	
//		TabularPart = Form[ChoiceValue.TabularPartName];
//	EndIf;
//	
//	SearchStructure = New Structure;
//	SearchStructure.Insert("Item", ChoiceValue.Item);
//	
//	InsertSearchStructure(SearchStructure, "Price", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));
//	InsertSearchStructure(SearchStructure, "InitialPrice", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));
//	InsertSearchStructure(SearchStructure, "Discount", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));
//	InsertSearchStructure(SearchStructure, "PricePromotion", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));

//	If IsManagedForm Then
//		
//	ElsIf ChoiceValue.Property("VATRate") AND 
//		ValueIsFilled(ChoiceValue.VATRate) AND
//		Common.IsDocumentTabularPartAttribute("VATRate", Form.Metadata(), ChoiceValue.TabularPartName) AND 
//		(Common.IsDocumentTabularPartAttribute("SalesQuota", Form.Metadata(), ChoiceValue.TabularPartName)
//		OR Common.IsDocumentTabularPartAttribute("SalesInvoice", Form.Metadata(), ChoiceValue.TabularPartName) 
//		OR Common.IsDocumentTabularPartAttribute("PurchaseQuota", Form.Metadata(), ChoiceValue.TabularPartName)
//		OR Common.IsDocumentTabularPartAttribute("SalesRetailQuota", Form.Metadata(), ChoiceValue.TabularPartName))Then
//		SearchStructure.Insert("VATRate", ChoiceValue.VATRate);
//	EndIf;
//	
//	InsertSearchStructure(SearchStructure, "Warehouse", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));

//	If IsManagedForm Then
//		
//	ElsIf Common.IsDocumentTabularPartAttribute("SalesQuota", Form.Metadata(), ChoiceValue.TabularPartName) Then
//		If ChoiceValue.Property("SalesQuota") Then
//			SearchStructure.Insert("SalesQuota", ?(ChoiceValue.SalesQuota=Undefined,Documents.SalesQuota.EmptyRef(),ChoiceValue.SalesQuota));
//		EndIf;	
//	EndIf;
//	
//	If IsManagedForm Then
//		
//	ElsIf Common.IsDocumentTabularPartAttribute("SalesRetailQuota", Form.Metadata(), ChoiceValue.TabularPartName) Then
//		If ChoiceValue.Property("SalesQuota") Then
//			SearchStructure.Insert("SalesRetailQuota", ?(ChoiceValue.SalesQuota=Undefined,Documents.SalesRetailQuota.EmptyRef(),ChoiceValue.SalesQuota));
//		EndIf;
//	EndIf;
//	
//	If IsManagedForm Then
//		
//	ElsIf Common.IsDocumentTabularPartAttribute("SalesInvoice", Form.Metadata(), ChoiceValue.TabularPartName) Then
//		If ChoiceValue.Property("SalesInvoice") Then
//			SearchStructure.Insert("SalesInvoice", ?(ChoiceValue.SalesInvoice=Undefined,Documents.SalesInvoice.EmptyRef(),ChoiceValue.SalesInvoice));
//		EndIf;	
//	EndIf;
//	
//	If IsManagedForm Then
//		
//	ElsIf Common.IsDocumentTabularPartAttribute("PurchaseQuota", Form.Metadata(), ChoiceValue.TabularPartName) Then
//		If ChoiceValue.Property("PurchaseQuota") Then
//			SearchStructure.Insert("PurchaseQuota", ChoiceValue.PurchaseQuota);
//		EndIf;	
//	EndIf;
//	
//	If AlwaysAddNewRow Then
//		ItemsLinesRow = Undefined;
//	Else	
//		ItemsLinesRow = Common.FindTabularPartRow(TabularPart, SearchStructure);
//	EndIf;	
//	
//	If ItemsLinesRow = Undefined Then
//		
//		ItemsLinesRow = TabularPart.Add();
//		If IsManagedForm Then
//			//??? LineNumber - Unwritable 
//			//ItemsLinesRow.LineNumber	= TabularPart.Count();
//		EndIf;
//		ItemsLinesRow.Item          = ChoiceValue.Item;
//		ItemsLinesRow.UnitOfMeasure = ChoiceValue.UnitOfMeasure;
//		
//		SetAttribute(ItemsLinesRow, "Warehouse", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));
//		SetAttribute(ItemsLinesRow, "Price", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));
//		SetAttribute(ItemsLinesRow, "InitialPrice", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));
//		SetAttribute(ItemsLinesRow, "PricePromotion", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));
//		SetAttribute(ItemsLinesRow, "Discount", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form));
//		
//		If IsManagedForm Then
//			
//		ElsIf Common.IsDocumentTabularPartAttribute("SalesInvoice", Form.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("SalesInvoice") Then
//				ItemsLinesRow.SalesInvoice     = ?(ChoiceValue.SalesInvoice=Undefined,Documents.SalesInvoice.EmptyRef(),ChoiceValue.SalesInvoice);			
//			EndIf;	
//		EndIf;
//		
//		If IsManagedForm Then
//			
//		ElsIf Common.IsDocumentTabularPartAttribute("SalesQuota", Form.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("SalesQuota") Then
//				ItemsLinesRow.SalesQuota     = ?(ChoiceValue.SalesQuota=Undefined,Documents.SalesQuota.EmptyRef(),ChoiceValue.SalesQuota);			
//			EndIf;	
//		EndIf;
//		
//		If IsManagedForm Then
//			
//		ElsIf Common.IsDocumentTabularPartAttribute("SalesRetailQuota", Form.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("SalesQuota") Then
//				ItemsLinesRow.SalesRetailQuota     = ?(ChoiceValue.SalesQuota=Undefined,Documents.SalesRetailQuota.EmptyRef(),ChoiceValue.SalesQuota);			
//			EndIf;	
//		EndIf;
//		
//		If IsManagedForm Then
//			
//		ElsIf Common.IsDocumentTabularPartAttribute("PurchaseQuota", Form.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("PurchaseQuota") Then
//				ItemsLinesRow.PurchaseQuota     = ChoiceValue.PurchaseQuota;
//			EndIf;	
//		EndIf;
//		
//		If IsManagedForm Then
//			
//		ElsIf Common.IsDocumentTabularPartAttribute("VATRate", Form.Metadata(), ChoiceValue.TabularPartName) Then
//			If ChoiceValue.Property("VATRate") 
//				AND ValueIsFilled(ChoiceValue.VATRate) 
//				AND (Common.IsDocumentTabularPartAttribute("SalesQuota", Form.Metadata(), ChoiceValue.TabularPartName)
//				OR Common.IsDocumentTabularPartAttribute("PurchaseQuota", Form.Metadata(), ChoiceValue.TabularPartName)
//				OR Common.IsDocumentTabularPartAttribute("SalesInvoice", Form.Metadata(), ChoiceValue.TabularPartName)
//				OR Common.IsDocumentTabularPartAttribute("SalesRetailQuota", Form.Metadata(), ChoiceValue.TabularPartName)) Then
//				ItemsLinesRow.VATRate      = ChoiceValue.VATRate;
//			ElsIf CommonAtServer.IsDocumentAttribute("Customer", Form.Metadata()) Then
//				ItemsLinesRow.VATRate      = TaxesAtClientAtServer.GetVATRate(Form.Company, Form.Customer.AccountingGroup, ItemsLinesRow.Item.AccountingGroup);
//			ElsIf CommonAtServer.IsDocumentAttribute("Supplier", Form.Metadata()) Then
//				ItemsLinesRow.VATRate      = TaxesAtClientAtServer.GetVATRate(Form.Company, Form.Supplier.AccountingGroup, ItemsLinesRow.Item.AccountingGroup);
//			EndIf;
//		EndIf;
//		
//	EndIf;
//	
//	SetAttribute(ItemsLinesRow, "Quantity", ChoiceValue, ?(IsManagedForm, AttributesStructure, Form), True);
//	
//	If IsManagedForm Then
//		If Not AttributesStructure = Undefined And AttributesStructure[ChoiceValue.TabularPartName].Find("Amount") = Undefined Then
//			If ValueIsFilled(ChoiceValue.Amount) Then
//				ItemsLinesRow.Amount        = ItemsLinesRow.Amount + ChoiceValue.Amount;
//			Else	
//				ItemsLinesRow.Amount        = GetItemsLinesRowAmount(ItemsLinesRow.Price, ItemsLinesRow.Quantity);
//			EndIf;	
//		EndIf;	
//		
//	ElsIf Common.IsDocumentTabularPartAttribute("Amount", Form.Metadata(), ChoiceValue.TabularPartName) Then
//		
//		If ValueIsFilled(ChoiceValue.Amount) Then
//			ItemsLinesRow.Amount        = ItemsLinesRow.Amount + ChoiceValue.Amount;
//		Else	
//			ItemsLinesRow.Amount        = GetItemsLinesRowAmount(ItemsLinesRow.Price, ItemsLinesRow.Quantity);
//		EndIf;	
//		
//	EndIf;
//	
//	If IsManagedForm Then
//		If Not AttributesStructure = Undefined And AttributesStructure[ChoiceValue.TabularPartName].Find("VAT") = Undefined Then
//			If ValueIsFilled(ChoiceValue.VAT) Then
//				ItemsLinesRow.VAT        = ItemsLinesRow.VAT + ChoiceValue.VAT;
//			Else	
//				ItemsLinesRow.VAT    = GetItemsLinesRowVATAmount(ItemsLinesRow.Amount, ItemsLinesRow.VATRate, Form.AmountType);
//			EndIf;	
//		EndIf;	
//	ElsIf Common.IsDocumentTabularPartAttribute("VAT", Form.Metadata(), ChoiceValue.TabularPartName) Then
//		If ValueIsFilled(ChoiceValue.VAT) Then
//			ItemsLinesRow.VAT        = ItemsLinesRow.VAT + ChoiceValue.VAT;
//		Else	
//			ItemsLinesRow.VAT    = GetItemsLinesRowVATAmount(ItemsLinesRow.Amount, ItemsLinesRow.VATRate, Form.AmountType);
//		EndIf;	
//	EndIf;
//	
//	If IsManagedForm Then
//		
//	Else
//		If Common.IsDocumentTabularPartAttribute("Quantity", Form.Metadata(), ChoiceValue.TabularPartName) Then
//			Form.Controls[ChoiceValue.TabularPartName].CurrentColumn = Form.Controls[ChoiceValue.TabularPartName].Columns.Quantity;
//		Else
//			Form.Controls[ChoiceValue.TabularPartName].CurrentColumn = Form.Controls[ChoiceValue.TabularPartName].Columns.Item;
//		EndIf;
//		Form.Controls[ChoiceValue.TabularPartName].CurrentRow    = ItemsLinesRow;
//	EndIf;
//	Return ItemsLinesRow;
//	
//EndFunction // PickUpRegularChoiceProcessing()

//Function CreatePickUpStructure(TabularPartName,Item,UnitOfMeasure,Price,Quantity,InitialPrice = 0,Discount = 0) Export
//	
//	Result = New Structure();
//	
//	Result.Insert("TabularPartName",TabularPartName);
//	Result.Insert("Item",Item);
//	Result.Insert("UnitOfMeasure",UnitOfMeasure);
//	Result.Insert("Price",?(Price = Undefined,0,Price));
//	Result.Insert("InitialPrice",InitialPrice);
//	Result.Insert("Discount",Discount);
//	Result.Insert("Quantity",Quantity);
//	Result.Insert("Amount",0);
//	Result.Insert("VAT",0);
//	
//	Return Result;
//	
//EndFunction 

//Procedure CalculateItemLinesRowWeightAndVolume(ItemsLinesRow,NeedToSetGrossWeight = False) Export 
//	
//	Selection = GetUnitOfMeasureWeightAndVolumeSelection(ItemsLinesRow.Item, ItemsLinesRow.UnitOfMeasure);
//	If Selection.Next() Then
//		If NeedToSetGrossWeight Then
//			ItemsLinesRow.GrossWeight = ItemsLinesRow.Quantity*Selection.GrossWeight;
//		EndIf;	
//		ItemsLinesRow.Weight = ItemsLinesRow.Quantity*Selection.Weight;
//		ItemsLinesRow.Volume = ItemsLinesRow.Quantity*Selection.Volume;
//	Else
//		If NeedToSetGrossWeight Then
//			ItemsLinesRow.GrossWeight = 0;
//		EndIf;	
//		ItemsLinesRow.Weight = 0;
//		ItemsLinesRow.Volume = 0;
//	EndIf;
//	
//EndProcedure // CalculateItemLinesRowWeightAndVolume()

//Function CalculateItemLinesRowWeight(ItemsLinesRow) Export
//	
//	Selection = GetUnitOfMeasureWeightAndVolumeSelection(ItemsLinesRow.Item, ItemsLinesRow.UnitOfMeasure);
//	If Selection.Next() Then
//		Return ItemsLinesRow.Quantity*Selection.Weight;
//	Else
//		Return 0;
//	EndIf;
//	
//EndFunction

//Function CalculateItemLinesRowVolume(ItemsLinesRow) Export
//	
//	Selection = GetUnitOfMeasureWeightAndVolumeSelection(ItemsLinesRow.Item, ItemsLinesRow.UnitOfMeasure);
//	If Selection.Next() Then
//		Return ItemsLinesRow.Quantity*Selection.Volume;
//	Else
//		Return 0;
//	EndIf;
//	
//EndFunction

//Function GetUnitOfMeasureWeightAndVolumeSelection(Item, UnitOfMeasure)
//	
//	Query = New Query;
//	Query.Text = "SELECT
//	             |	ItemsUnitsOfMeasure.Weight,
//	             |	ItemsUnitsOfMeasure.Volume,
//	             |	ItemsUnitsOfMeasure.GrossWeight
//	             |FROM
//	             |	Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasure
//	             |WHERE
//	             |	ItemsUnitsOfMeasure.Ref = &Item
//	             |	AND ItemsUnitsOfMeasure.UnitOfMeasure = &UnitOfMeasure";
//	
//	Query.SetParameter("Item", Item);
//	Query.SetParameter("UnitOfMeasure", UnitOfMeasure);
//	
//	Return Query.Execute().Select();
//	
//EndFunction


Procedure CleanMovementsInRegister(RegisterName, Ref) Export 
	
	RecordSet = AccumulationRegisters[RegisterName].CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Ref);
	RecordSet.Read();
	RecordSet.Clear();
	RecordSet.Write();
	
EndProcedure // CleanMovementsInRegister()

Procedure ShowHideColumns(Visibility, Control, ColumnsStructure) Export 
	
	For Each KeyAndValue In ColumnsStructure Do
		
		Control.Columns[KeyAndValue.Key].Visible = Visibility;
		
	EndDo;	
	
EndProcedure	

Procedure ShowHideNationalColumns(Currency, Control, ColumnsStructure) Export 
	If Currency = Constants.NationalCurrency.Get() Then
		Visible = False;
	Else
		Visible = True;
	EndIf;	
	For Each KeyAndValue In ColumnsStructure Do
		Control.Columns[KeyAndValue.Key].Visible = Visible;
	EndDo;	
EndProcedure	


////  Table1, Table2 - tables to compare
////  Key1, Key2 - keys for tables by which will be found rows to comparation. Should be key column name
////  ColumnsCorrespondence - Structure which contains As key - column name for table1, 
////   and as value - column name for table2

// Jack 29.05.2017
//Function CompareTables(Val Table1, Key1, Val Table2, Key2, ColumnsCorrespondence) Export
//	
//	Result = False;
//	
//	If Table1.Count()<>Table2.Count() Then
//		Return Result;
//	EndIf;
//	
//	For Each Table1Row In Table1 Do
//		
//		FoundTable1Rows = Table1.FindRows(New Structure(Key1,Table1Row[Key1]));
//		FoundTable2Rows = Table2.FindRows(New Structure(Key2,Table1Row[Key1]));
//		
//		If FoundTable1Rows.Count()<>FoundTable2Rows.Count() Then
//			Return Result;
//		EndIf;
//		
//		For i=0 To FoundTable1Rows.Count()-1 Do
//			For Each ColumnsCorrespondenceItem In ColumnsCorrespondence Do
//				
//				Table1RowToCompare = FoundTable1Rows[i];
//				Table2RowToCompare = FoundTable2Rows[i];
//				
//				If Table1RowToCompare[ColumnsCorrespondenceItem.Key] <> Table2RowToCompare[ColumnsCorrespondenceItem.Value] Then
//					Return Result;
//				EndIf;	
//				
//			EndDo;	
//		EndDo;	
//		
//	EndDo;	
//		
//	Result = True;
//	
//	Return Result;
//		
//EndFunction	

// LOADING FROM SPREADSHEET

// ObjectRef - Reference on object. Used to take types and synonymes of columns
// TabularSectionName - Tabular section name
// ColumnsStructure - as key used column name in tabulart section, as value can be used column title. 
// If ColumnsStructure is empty then all columns with the types will be got for tabular section
//							- if value is filled, then procedure redefine type got from tabulart section by this value
// Form - need to unique opening data processor 
// Object - need for properly work of alerts mechanics 
// ColumnsTypesStructure - if columns types should be taken not from TabularSection attributes, then this structure
//							should contain as key - column name and as value - column type
Procedure OpenLoadingFromSpreadsheet(ObjectRef,TabularSectionName,ColumnsStructure = Undefined,Object = Undefined,Form = Undefined,ColumnsTypesStructure = Undefined,DontShowNotificationStructure = Undefined,AdditionalProperties = Undefined) Export
	
	Alerts.ClearAlertsTable(Object,Form);
	
	If TypeOf(DontShowNotificationStructure) <> Type("Structure") Then
		DontShowNotificationStructure = New Structure;
	EndIf;
	
	LoadingForm = DataProcessors.LoadingDataFromSpreadsheet.GetForm("Form", Form, Form);
	
	RefMetadata = ObjectRef.Metadata();
	
	TabularSectionAttributes = RefMetadata.TabularSections[TabularSectionName].Attributes;
	
	TabularPartValueTable = New ValueTable;
	
	If ColumnsStructure = Undefined Then
		// columns order from metadata	
		For Each Attribute In TabularSectionAttributes Do
			
			TabularPartValueTable.Columns.Add(Attribute.Name, Attribute.Type ,Attribute.Synonym);
			
		EndDo;

	Else
		// order from structure
		For Each StructureItem In ColumnsStructure Do
			
			Try
				Attribute = TabularSectionAttributes[StructureItem.Key];
			Except
				Attribute = Undefined
			EndTry;	
			
			StructureItemType = Undefined;
			If ColumnsTypesStructure <> Undefined Then
				ColumnsTypesStructure.Property(StructureItem.Key,StructureItemType);
			EndIf;	

			If Attribute = Undefined Then
				TabularPartValueTable.Columns.Add(StructureItem.Key, StructureItemType, StructureItem.Value);
			Else
				TabularPartValueTable.Columns.Add(Attribute.Name, ?(StructureItemType = Undefined,Attribute.Type,StructureItemType), Attribute.Synonym);
			EndIf;
			
		EndDo;	
		
	EndIf;
		
	LoadingForm.TabularPartValueTable = TabularPartValueTable;
	LoadingForm.Object = Object;
	LoadingForm.TabularPartName = TabularSectionName;
	LoadingForm.InternalDataLoading = True;
	LoadingForm.DontShowNotificationStructure = DontShowNotificationStructure;
	LoadingForm.AdditionalProperties = AdditionalProperties;
	
	LoadingForm.Open();

EndProcedure


Function FillTabularSectionOnLoadingFromSpreadsheetResult(TabularSection,LoadingFromSpreadsheetResult, GroupingColumns = "", TotalingColumns = "") Export
	
	If LoadingFromSpreadsheetResult.Overwrite Then
		TabularSection.Clear();
	EndIf;	
	
	TabularPartValueTable = LoadingFromSpreadsheetResult.TabularPartValueTable;
	
	AddedRowsArray = New Array();
	
	For Each TabularPartValueTableRow In TabularPartValueTable Do
		
		NewTabularSectionRow = TabularSection.Add();
		AddedRowsArray.Add(NewTabularSectionRow);
		
		For Each Column In TabularPartValueTable.Columns Do
			
			Try
				NewTabularSectionRow[Column.Name] = TabularPartValueTableRow[Column.Name];
			Except
			EndTry;	
			
		EndDo;	
		
	EndDo;	
	
	If Not IsBlankString(GroupingColumns) 
		AND Not IsBlankString(TotalingColumns) Then
		
		TabularSection.GroupBy(GroupingColumns,TotalingColumns);
		
	EndIf;	
	
	Return AddedRowsArray;
	
EndFunction	
