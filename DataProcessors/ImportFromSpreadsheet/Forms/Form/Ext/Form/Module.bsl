&AtClient
Procedure FilePathStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("SelectExternalFileDataProcessorEnd", ThisObject);
	BeginPutFile(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure SelectExternalFileDataProcessorEnd(Result, Address, FileName, AdditionalParameters) Export
	
	If Result = True Then
		
		PathToFile = FileName;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAttributes()

	IsProductsAndServices = OperationKind = "ProductsAndServices";
	IsCounterparties = OperationKind = "Counterparties";
	IsBalance = OperationKind = "Balance";
	IsPrice = OperationKind = "Prices";
	
	Items.ImportingListSKU.Visible = IsProductsAndServices;
	Items.ImportingListCode.Visible = IsProductsAndServices;
	Items.ImportingListVAT.Visible = IsProductsAndServices;
	
	Items.BarcodeExportList.Visible = IsProductsAndServices;
	
	Items.ImportingListDescriptionFull.Visible = IsCounterparties;
	Items.ImportingListTIN.Visible = IsCounterparties;
	Items.ImportingListCRR.Visible = IsCounterparties;
	
	Items.ImportingListQuantity.Visible = IsBalance;
	Items.CCDNoExportList.Visible = IsBalance;
	Items.Warehouse.Visible = IsBalance;
	
	Items.CountryOfOrigin.Visible = IsBalance OR IsProductsAndServices OR IsPrice;
	
	If IsBalance OR IsPrice Then
		Items.CountryOfOrigin.InputHint = "Write the country of origin for new ProductsAndServices";
	Else
		Items.CountryOfOrigin.InputHint = "Specify country of origin";
	EndIf;
	
	Items.ImportingListPrice.Visible = IsBalance OR IsPrice;
	Items.ImportingListComment.Visible = IsProductsAndServices OR IsCounterparties;
	Items.PriceKind.Visible = IsPrice;
	Items.Date.Visible = IsBalance OR IsPrice;
	
	Attributes.Clear();
	NewRow = Attributes.Add();
	NewRow.AttributeName = "Description";
	NewRow.IsRequired = True;
	
	If IsProductsAndServices Then
			
		NewRow = Attributes.Add();
		NewRow.AttributeName = "SKU";
		NewRow = Attributes.Add();
		NewRow.AttributeName = "Code";
		NewRow = Attributes.Add();
		NewRow.AttributeName = "VAT";
		NewRow = Attributes.Add();
		NewRow.AttributeName = "Stroke-code";
		NewRow = Attributes.Add();
		NewRow.AttributeName = "Comment";
		
	ElsIf IsCounterparties Then
		
		NewRow = Attributes.Add();
		NewRow.AttributeName = "DescriptionFull";
		NewRow = Attributes.Add();
		NewRow.AttributeName = "TIN";
		NewRow = Attributes.Add();
		NewRow.AttributeName = "KPP";
		NewRow = Attributes.Add();
		NewRow.AttributeName = "Comment";
		
	ElsIf IsBalance Then
	
		NewRow = Attributes.Add();
		NewRow.AttributeName = "Quantity";
		NewRow.IsRequired = True;
		NewRow = Attributes.Add();
		NewRow.AttributeName = "Price";
		NewRow = Attributes.Add();
		NewRow.AttributeName = "CCD";
		
	ElsIf IsPrice Then
	
		NewRow = Attributes.Add();
		NewRow.AttributeName = "Price";
		NewRow.IsRequired = True;
		
	EndIf;
	
EndProcedure // FillAttributes()

&AtServer
Function FillSourceAtServer(LineCount)
	
	Source = New ValueTable;
	
	MaxColumnCount = 0;
	
	For RowCounter = 1 To LineCount Do
		
		CurrentRow = SourceText.GetLine(RowCounter);
		ValueArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(CurrentRow, ";");
		ColumnsCount = ValueArray.Count();
		
		If ColumnsCount < 1 Then
			Continue;
		EndIf;
		
		If ColumnsCount > MaxColumnCount Then
			For ColumnCounter = MaxColumnCount + 1 To ColumnsCount Do
				NewColumn = Source.Columns.Add();
				NewColumn.Name = "Column" + TrimAll(ColumnCounter);
				NewColumn.Title = "Column No" + TrimAll(ColumnCounter);
			EndDo;
			MaxColumnCount = ColumnsCount;
		EndIf;
		
		NewRow = Source.Add();
		For ColumnCounter = 0 To ColumnsCount - 1 Do
			NewRow[ColumnCounter] = ValueArray[ColumnCounter];
		EndDo;
		
	EndDo;
	
	SourceAddress = PutToTempStorage(Source, ThisForm.UUID);
	
	Return SourceAddress;
	
EndFunction

&AtClient
Procedure ReadFileSource()
	
	FileUpl 			= New File;
	FilePathWithoutSpaces= TrimAll(PathToFile);
	NotifyDescription	= New NotifyDescription("InitializationFileEnd", ThisObject, New Structure("File", FilePathWithoutSpaces));
	FileUpl.BeginInitialization(NOTifyDescription, FilePathWithoutSpaces);
	
EndProcedure

&AtClient
Procedure InitializationFileEnd(ObjectFile, AdditionalParameters) Export
	
	NotifyDescription	= New NotifyDescription("ReadFileSourceEnd", ThisObject, AdditionalParameters);
	ObjectFile.BeginCheckingExistence(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure ReadFileSourceEnd(Exist, AdditionalParameters) Export
	
	File = AdditionalParameters.File;
	If Exist Then
		
		Try
			
			SourceText.Read(File);
			LineCount = SourceText.LineCount();
			If LineCount < 1 Then
				
				MessageText = NStr("en = 'There is no data in the file!'");
				SmallBusinessServer.ShowMessageAboutError(, MessageText);
				
			Else
				
				SourceAddress = Undefined;
				SourceAddress = FillSourceAtServer(LineCount);
				If Not ValueIsFilled(SourceAddress) Then
					Return;
				EndIf;
				
				FillSourcePresentation();
				Items.ImportingStages.CurrentPage = Items.ImportingStages.ChildItems.Mapping;
				
			EndIf;
			
		Except
			
			MessageText = NStr("en = 'File is not read.'");
			SmallBusinessServer.ShowMessageAboutError(, MessageText);
			
		EndTry;
		
	Else
		
		MessageText = NStr("en = 'File %File% does not exist!'");
		MessageText = StrReplace(MessageText, "%File%", File);
		SmallBusinessServer.ShowMessageAboutError(, MessageText);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSourcePresentation()

	SourcePresentation.Clear();
	
	DataProcessor = FormAttributeToValue("Object");
	Template = DataProcessor.GetTemplate("Template");
	AreaIsEmpty = Template.GetArea("IsEmpty");
	AreaHeader = Template.GetArea("Header");
	AreaCell = Template.GetArea("Cell");
	
	Source = GetFromTempStorage(SourceAddress);

	SourcePresentation.Put(AreaIsEmpty);
	For Each SourceColumn IN Source.Columns Do
		AreaHeader.Parameters.Text = SourceColumn.Title;
		SourcePresentation.Join(AreaHeader);
	EndDo;
	
	ColumnsCount = Source.Columns.Count();
	For Each SourceRow IN Source Do
		SourcePresentation.Put(AreaIsEmpty);
		For ColumnCounter = 0 To ColumnsCount -1  Do
			AreaCell.Parameters.Text = SourceRow[ColumnCounter];
			SourcePresentation.Join(AreaCell);
		EndDo;
	EndDo;
	
	Items.AttributesColumnNumber.MaxValue = Source.Columns.Count();
	
EndProcedure

&AtServer
Procedure FillImportingList()
	
	Object.ImportingList.Clear();
	ImportingTable = Object.ImportingList.Unload();
	
	Source = GetFromTempStorage(SourceAddress);
	
	If OperationKind = "Counterparties" Then
		Manager = Catalogs.Counterparties;
	ElsIf OperationKind = "ProductsAndServices"
		  OR OperationKind = "Prices"
		  OR OperationKind = "Balance" Then
		Manager = Catalogs.ProductsAndServices;
	Else
		Return;
	EndIf;
	
	For RowCounter = 0 to Source.Count() - 1 Do
		
		If OperationKind = "Prices" OR OperationKind = "Balance" Then
			
			ColumnNumber = FindAttributeColumnNumber(?(OperationKind = "Prices", "Price", "Quantity"));
			If ColumnNumber = Undefined Then
				Continue;
			Else
				Try
					StringNumber = Source[RowCounter][ColumnNumber - 1];
					StringNumber = StrReplace(StringNumber, " ", "");
					StringNumber = StrReplace(StringNumber, "'", "");
					If Number(StringNumber) = 0 Then
						MessageText = NStr("en='String No%LineNumber% can not be imported because value in the %ColumnNo% column is equal to 0.'");
						MessageText = StrReplace(MessageText, "%LineNumber%", String(RowCounter+1));
						MessageText = StrReplace(MessageText, "%ColumnNumber%", ColumnNumber+1);
						Message = New UserMessage;
						Message.Text = MessageText;
						Message.Message();
						Continue;
					EndIf;
				Except
					MessageText = NStr("en='String No%LineNumber% can not be imported because value in the %ColumnNo% column is not a number.'");
					MessageText = StrReplace(MessageText, "%LineNumber%", String(RowCounter+1));
					MessageText = StrReplace(MessageText, "%ColumnNumber%", ColumnNumber+1);
					Message = New UserMessage;
					Message.Text = MessageText;
					Message.Message();
					Continue;
				EndTry;
			EndIf;
		EndIf;
		
		Description = "";
		DescriptionFull = "";
		
		ColumnNumber = FindAttributeColumnNumber("Description");
		If ColumnNumber <> Undefined Then
			Description = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		
		ColumnNumber = FindAttributeColumnNumber("DescriptionFull");
		If ColumnNumber <> Undefined Then
			DescriptionFull = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		
		NameForSearch = Left(Description, 100);
		
		Ref = Manager.FindByDescription(NameForSearch);
		
		NewRow = ImportingTable.Add();
		NewRow.Description = Description;
		NewRow.Ref = Ref;
		NewRow.IsNew = Ref.IsEmpty();
		
		ColumnNumber = FindAttributeColumnNumber("SKU");
		If ColumnNumber <> Undefined Then
			NewRow.SKU = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("Code");
		If ColumnNumber <> Undefined Then
			NewRow.Code = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("VAT");
		If ColumnNumber <> Undefined Then
			NewRow.VAT = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("Stroke-code");
		If ColumnNumber <> Undefined Then
			NewRow.Barcode = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("Comment");
		If ColumnNumber <> Undefined Then
			NewRow.Comment = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("DescriptionFull");
		If ColumnNumber <> Undefined Then
			NewRow.DescriptionFull = DescriptionFull;
		Else
			NewRow.Description = Description;
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("TIN");
		If ColumnNumber <> Undefined Then
			NewRow.TIN = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("KPP");
		If ColumnNumber <> Undefined Then
			NewRow.KPP = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("Price");
		If ColumnNumber <> Undefined Then
			StringNumber = TrimAll(Source[RowCounter][ColumnNumber - 1]);
			StringNumber = StrReplace(StringNumber, " ", "");
			StringNumber = StrReplace(StringNumber, "'", "");
			NewRow.Price = StringNumber;
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("CCD");
		If ColumnNumber <> Undefined Then
			NewRow.CCDNo = TrimAll(Source[RowCounter][ColumnNumber - 1]);
		EndIf;
		ColumnNumber = FindAttributeColumnNumber("Quantity");
		If ColumnNumber <> Undefined Then
			StringNumber = TrimAll(Source[RowCounter][ColumnNumber - 1]);
			StringNumber = StrReplace(StringNumber, " ", "");
			StringNumber = StrReplace(StringNumber, "'", "");
			NewRow.Quantity = StringNumber;
		EndIf;
		
		If OperationKind = "Prices"
		 OR OperationKind = "Balance" Then
			NewRow.ImportingFlag = True;
		Else
			NewRow.ImportingFlag = NewRow.IsNew;
		EndIf;
		
	EndDo;
	
	ImportingTable.GroupBy("Description,Ref,IsNew,SKU,Code,VAT,Barcode,CCDNo,Comment,DescriptionFull,TIN,KPP,Price,ImportingFlag","Quantity");
	
	Object.ImportingList.Load(ImportingTable);
	
EndProcedure

&AtServer
Function FindAttributeColumnNumber(AttributeName)
	
	FoundAttribute = Undefined;
	FoundStrings = Attributes.FindRows(New Structure("AttributeName", AttributeName));
	If FoundStrings.Count() > 0 Then
		FoundAttribute = FoundStrings[0].ColumnNumber;
	EndIf;
	
	Return ?(FoundAttribute = 0, Undefined, FoundAttribute);
	
EndFunction

Function FindCreateCCDNumber(Number)

	Manager = Catalogs.CCDNumbers;
	Ref = Manager.FindByCode(Number);
	If Ref.IsEmpty() Then
		NumberObject = Manager.CreateItem();
		NumberObject.Code = Number;
		NumberObject.Write();
		Ref = NumberObject.Ref;
	EndIf;

	Return Ref;
	
EndFunction // FindCreateCCDNumber()

Function FindVatRate(Rate)
	
	If IsBlankString(Rate) Then
		Return Undefined;
	EndIf;
	
	Manager = Catalogs.VATRates;
	Ref = Manager.FindByDescription(TrimAll(Rate), True);
	If Not Ref.IsEmpty() Then
		Return Ref;
	EndIf;
	
	Try
		
		BidAmount = Number(TrimAll(Rate));
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	VATRates.Ref
		|FROM
		|	Catalog.VATRates AS VATRates
		|WHERE
		|	VATRates.Rate = &BidAmount";
		
		Query.SetParameter("BidAmount", BidAmount);
		
		Result = Query.Execute().Unload();
		If Result.Count() > 0 Then
			Return Result[0].Ref;
		EndIf;
		
	Except
	
	EndTry;
	
	Return Undefined;
	
EndFunction // FindVatRate()

&AtServer
Procedure Import(Cancel)
	
	If Object.ImportingList.Count() = 0 Then
		Return;
	EndIf;
	
	FormAttributeToValue("Object").CheckDuplicatesOfRows(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If OperationKind = "Prices" Then
		Manager = Catalogs.ProductsAndServices;
	ElsIf OperationKind = "Balance" Then
		DocumentInputBalances = Documents.EnterOpeningBalance.CreateDocument();
		DocumentInputBalances.AccountingSection = "Inventory";
		DocumentInputBalances.Company = Catalogs.Companies.MainCompany;
		DocumentInputBalances.Date = ?(ValueIsFilled(Date), Date, CurrentDate());
		DocumentInputBalances.Comment = "# Document is entered by data import processing from electronic table.";
		Manager = Catalogs.ProductsAndServices;
	ElsIf OperationKind = "ProductsAndServices" Then
		Manager = Catalogs.ProductsAndServices;
	ElsIf OperationKind = "Counterparties" Then
		Manager = Catalogs.Counterparties;
	EndIf;
	
	For Each ImportRow IN Object.ImportingList Do
	
		If Not ImportRow.ImportingFlag Then
			Continue;
		EndIf;
		
		If ImportRow.Ref.IsEmpty() Then
			ObjectToWrite = Manager.CreateItem();
		Else
			ObjectToWrite = ImportRow.Ref.GetObject();
		EndIf;
		
		If OperationKind = "Counterparties" Then
			
			FillPropertyValues(ObjectToWrite, ImportRow);
			ObjectToWrite.DescriptionFull = ObjectToWrite.DescriptionFull;
			If StrLen(ObjectToWrite.TIN) = 12 Then
				ObjectToWrite.LegalEntityIndividual = Enums.LegalEntityIndividual.Ind;
			Else
				ObjectToWrite.LegalEntityIndividual = Enums.LegalEntityIndividual.LegalEntity;
			EndIf;
			ObjectToWrite.GLAccountCustomerSettlements = ChartsOfAccounts.Managerial.AccountsReceivable;
			ObjectToWrite.CustomerAdvancesGLAccount = ChartsOfAccounts.Managerial.AccountsByAdvancesReceived;
			ObjectToWrite.GLAccountVendorSettlements = ChartsOfAccounts.Managerial.AccountsPayable;
			ObjectToWrite.VendorAdvancesGLAccount = ChartsOfAccounts.Managerial.SettlementsByAdvancesIssued;
			ObjectToWrite.DoOperationsByContracts = True;
			ObjectToWrite.DoOperationsByDocuments = True;
			ObjectToWrite.DoOperationsByOrders = True;
			ObjectToWrite.TrackPaymentsByBills = True;
			ObjectToWrite.Write();
			
		ElsIf OperationKind = "ProductsAndServices" Then
			
			FillPropertyValues(ObjectToWrite, ImportRow);
			ObjectToWrite.DescriptionFull = ImportRow.Description;
			ObjectToWrite.MeasurementUnit = Catalogs.UOMClassifier.pcs;
			ObjectToWrite.ProductsAndServicesCategory = Catalogs.ProductsAndServicesCategories.MainGroup;
			ObjectToWrite.InventoryGLAccount = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
			ObjectToWrite.ExpensesGLAccount = ChartsOfAccounts.Managerial.UnfinishedProduction;
			ObjectToWrite.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
			ObjectToWrite.EstimationMethod = Enums.InventoryValuationMethods.ByAverage;
			ObjectToWrite.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
			ObjectToWrite.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
			ObjectToWrite.CountryOfOrigin = CountryOfOrigin;
			
			VATRate = FindVatRate(ImportRow.VAT);
			If VATRate <>Undefined Then
				ObjectToWrite.VATRate = VATRate;
			Else
				ObjectToWrite.VATRate = ?(ValueIsFilled(ObjectToWrite.VATRate), ObjectToWrite.VATRate, Catalogs.Companies.MainCompany.DefaultVATRate);
			EndIf;
			
			ObjectToWrite.Write();
			
			If ValueIsFilled(ImportRow.Barcode) Then
				RecordSetProductsAndServicesBarcodes = InformationRegisters.ProductsAndServicesBarcodes.CreateRecordSet();
				RecordSetProductsAndServicesBarcodes.Filter.Barcode.Set(ImportRow.Barcode);
				NewRow = RecordSetProductsAndServicesBarcodes.Add();
				NewRow.ProductsAndServices = ObjectToWrite.Ref;
				NewRow.Barcode = ImportRow.Barcode;
				RecordSetProductsAndServicesBarcodes.Write(True);
			EndIf;
			
		ElsIf OperationKind = "Prices" Then
			
			If Not ValueIsFilled(ObjectToWrite.Ref) Then
				
				FillPropertyValues(ObjectToWrite, ImportRow);
				ObjectToWrite.DescriptionFull = ImportRow.Description;
				ObjectToWrite.MeasurementUnit = Catalogs.UOMClassifier.pcs;
				ObjectToWrite.ProductsAndServicesCategory = Catalogs.ProductsAndServicesCategories.MainGroup;
				ObjectToWrite.InventoryGLAccount = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
				ObjectToWrite.ExpensesGLAccount = ChartsOfAccounts.Managerial.UnfinishedProduction;
				ObjectToWrite.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
				ObjectToWrite.EstimationMethod = Enums.InventoryValuationMethods.ByAverage;
				ObjectToWrite.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
				ObjectToWrite.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
				ObjectToWrite.CountryOfOrigin = CountryOfOrigin;
				
				VATRate = FindVatRate(ImportRow.VAT);
				If VATRate <>Undefined Then
					ObjectToWrite.VATRate = VATRate;
				Else
					ObjectToWrite.VATRate = ?(ValueIsFilled(ObjectToWrite.VATRate), ObjectToWrite.VATRate, Catalogs.Companies.MainCompany.DefaultVATRate);
				EndIf;
				
				ObjectToWrite.Write();
				
			EndIf;
			
			RecordSetProductsAndServicesPrices = InformationRegisters.ProductsAndServicesPrices.CreateRecordSet();
			RecordSetProductsAndServicesPrices.Filter.Period.Set(?(ValueIsFilled(Date), Date, CurrentDate()));
			RecordSetProductsAndServicesPrices.Filter.PriceKind.Set(?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceKinds.Wholesale));
			RecordSetProductsAndServicesPrices.Filter.ProductsAndServices.Set(ObjectToWrite.Ref);
			RecordSetProductsAndServicesPrices.Filter.Characteristic.Set(Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
			NewRow = RecordSetProductsAndServicesPrices.Add();
			NewRow.ProductsAndServices = ObjectToWrite.Ref;
			NewRow.PriceKind = ?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceKinds.Wholesale);
			NewRow.Actuality = True;
			NewRow.Period = ?(ValueIsFilled(Date), Date, CurrentDate());
			NewRow.Price = ImportRow.Price;
			NewRow.MeasurementUnit = Catalogs.UOMClassifier.pcs;
			RecordSetProductsAndServicesPrices.Write(True);
			
		ElsIf OperationKind = "Balance" Then
			
			If Not ValueIsFilled(ObjectToWrite.Ref) Then
				
				FillPropertyValues(ObjectToWrite, ImportRow);
				ObjectToWrite.DescriptionFull = ImportRow.Description;
				ObjectToWrite.MeasurementUnit = Catalogs.UOMClassifier.pcs;
				ObjectToWrite.ProductsAndServicesCategory = Catalogs.ProductsAndServicesCategories.MainGroup;
				ObjectToWrite.InventoryGLAccount = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
				ObjectToWrite.ExpensesGLAccount = ChartsOfAccounts.Managerial.UnfinishedProduction;
				ObjectToWrite.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
				ObjectToWrite.EstimationMethod = Enums.InventoryValuationMethods.ByAverage;
				ObjectToWrite.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
				ObjectToWrite.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
				ObjectToWrite.CountryOfOrigin = CountryOfOrigin;
				
				VATRate = FindVatRate(ImportRow.VAT);
				If VATRate <>Undefined Then
					ObjectToWrite.VATRate = VATRate;
				Else
					ObjectToWrite.VATRate = ?(ValueIsFilled(ObjectToWrite.VATRate), ObjectToWrite.VATRate, Catalogs.Companies.MainCompany.DefaultVATRate);
				EndIf;
				
				ObjectToWrite.Write();
				
			EndIf;
			
			If ValueIsFilled(ImportRow.CCDNo) Then
				NewRow = DocumentInputBalances.InventoryByCCD.Add();
				NewRow.ProductsAndServices = ObjectToWrite.Ref;
				NewRow.Quantity = ImportRow.Quantity;
				NewRow.MeasurementUnit = Catalogs.UOMClassifier.pcs;
				If Not ValueIsFilled(ObjectToWrite.Ref.CountryOfOrigin) Then
					Cancel = True;
					Message("in the ProductsAndServices card " + TrimAll(NewRow.ProductsAndServices) + " Country of origin is not filled!");
				EndIf;
				NewRow.CountryOfOrigin = ObjectToWrite.Ref.CountryOfOrigin;
				NewRow.CCDNo = FindCreateCCDNumber(ImportRow.CCDNo);
			EndIf;
			
			If ObjectToWrite.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
				NewRow = DocumentInputBalances.Inventory.Add();
				NewRow.ProductsAndServices = ObjectToWrite.Ref;
				NewRow.Quantity = ImportRow.Quantity;
				NewRow.Price = ImportRow.Price;
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				NewRow.MeasurementUnit = Catalogs.UOMClassifier.pcs;
				NewRow.StructuralUnit = ?(ValueIsFilled(Warehouse), Warehouse, Catalogs.StructuralUnits.MainWarehouse);
			Else
				Message("Position """ + TrimAll(ObjectToWrite.Ref)+""" is service, its balance will not be imported!");
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If Cancel Then
		Message("During import, errors occurred. Data will not be imported.");
		Return;
	EndIf;
	
	If OperationKind = "Balance" Then
		DocumentInputBalances.Write(DocumentWriteMode.Posting);
	EndIf;
	
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	FillAttributes();
	
EndProcedure

&AtClient
Procedure GreetingNext(Command)
	
	If AttachFileSystemExtension() AND
		Not ValueIsFilled(PathToFile) Then
		
		MessageText = NStr("en='First specify path to the file to load!'");
		ShowMessageBox(Undefined,MessageText);
		Return;
		
	EndIf;
	
	If Attributes.Count() = 0 Then
		
		FillAttributes();
		
	EndIf;
	
	Items.MappingGroup.Title = PathToFile;
	ReadFileSource();
	
EndProcedure

&AtClient
Procedure MappingBack(Command)
	
	Items.ImportingStages.CurrentPage = Items.ImportingStages.ChildItems.Greeting;
	
EndProcedure

&AtClient
Procedure MappingNext(Command)
	
	For AttributeCounter = 0 to Attributes.Count() - 1 Do
		If Attributes[AttributeCounter].IsRequired and Attributes[AttributeCounter].ColumnNumber = 0 Then
			Message = New UserMessage;
			Message.Text = "It is required  to fill the necessary attribute columns";
			Message.Field = "Attributes[0].ColumnNumber";
			Message.Message(); 
			Return;
		EndIf; 
	EndDo;
	
	FillImportingList();
	Items.ImportingStages.CurrentPage = Items.ImportingStages.ChildItems.Creating;
	
EndProcedure

&AtClient
Procedure CreatingMarkAll(Command)
	
	For Each Item IN Object.ImportingList Do
		Item.ImportingFlag = True;
	EndDo; 
	
EndProcedure

&AtClient
Procedure CreatingUnmarkCheck(Command)
	
	For Each Item IN Object.ImportingList Do
		Item.ImportingFlag = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure MarkNewOnly(Command)
	
	For Each Item IN Object.ImportingList Do
		Item.ImportingFlag = Item.IsNew;
	EndDo;
	
EndProcedure

&AtClient
Procedure CreatingBack(Command)
	
	Items.ImportingStages.CurrentPage = Items.ImportingStages.ChildItems.Mapping;
	
EndProcedure

&AtClient
Procedure CreationForward(Command)
	
	Cancel = False;
	ClearMessages();
	Import(Cancel);
	If Not Cancel Then
		Items.ImportingStages.CurrentPage = Items.ImportingStages.ChildItems.End;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefToListClick(Item)
	
	If OperationKind = "Counterparties" Then
		OpenForm("Catalog.Counterparties.ListForm");
	ElsIf OperationKind = "ProductsAndServices" Then
		OpenForm("Catalog.ProductsAndServices.ListForm");
	ElsIf OperationKind = "Prices" Then
		OpenForm("DataProcessor.PriceList.Form");
	ElsIf OperationKind = "Balance" Then
		OpenForm("Document.EnterOpeningBalance.ListForm");
	EndIf;
	
EndProcedure

&AtClient
Procedure Done(Command)
	
	ThisForm.Close();
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	OperationKind = Parameters.OperationKind;
	FillAttributes();
	Warehouse = Catalogs.StructuralUnits.MainWarehouse;
	PriceKind = Catalogs.PriceKinds.Wholesale;
	Date = CurrentDate();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	NotifyDescription = New NotifyDescription("ExtensionConnectionOfFilesWorksEnd", ThisObject);
	BeginAttachingFileSystemExtension(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure ExtensionConnectionOfFilesWorksEnd(Attached, AdditionalParameters) Export
	
	If Attached Then
		
		Items.PathToFile.Visible = True;
		Items.WarningExporting.Visible = False;
		
	Else
		
		NotifyDescription = New NotifyDescription("ExtensionSettingOfFilesWorksEnd", ThisObject);
		BeginInstallFileSystemExtension();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExtensionSettingOfFilesWorksEnd(AdditionalParameters) Export
	
	Items.PathToFile.Visible = True;
	Items.WarningExporting.Visible = False;
	
EndProcedure

&AtClient
Procedure PathToFileOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	TextDoc = New TextDocument();
	TextDoc.Read(PathToFile);
	TextDoc.Show(PathToFile, PathToFile);
	
EndProcedure
