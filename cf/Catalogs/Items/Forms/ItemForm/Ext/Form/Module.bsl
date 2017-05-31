&AtClient
Var JobStructure;

#Region BaseFormsProcedures
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	FormsAtServer.CatalogFormOnCreateAtServer(ThisForm, Cancel, StandardProcessing);
	
	ReadUnitsOfMeasure();
	
	IsAccessRightSalesPrices = Privileged.IsAccessRight(Metadata.InformationRegisters.SalesPrices, "View");
	Items.GroupPrice.Visible = IsAccessRightSalesPrices;
	If IsAccessRightSalesPrices Then
		AddPriceItems();
	EndIf;
	
	IsAccessRightSalesPricePromotions = Privileged.IsAccessRight(Metadata.InformationRegisters.SalesPricePromotions);
	Items.GroupPricePromotions.Visible = IsAccessRightSalesPricePromotions;
	If IsAccessRightSalesPricePromotions Then
		ReadPricePromotions();
	EndIf;
	
	ReadBarCodes();
	
	If Not ValueIsFilled(Object.MainPicture) Then
		Query = New Query;
		Query.Text = "SELECT
		             |	Files.Ref
		             |FROM
		             |	Catalog.Files AS Files
		             |WHERE
		             |	Files.DeletionMark = FALSE
		             |	AND Files.RefObject = &RefObject
		             |
		             |ORDER BY
		             |	Files.Code";
		
		Query.SetParameter("RefObject", Object.Ref);
		
		If Query.Execute().Unload().Count() = 0 Then
			Items.GroupPictureSetting.Visible = False;
		Else
			Items.GroupPictureSetting.Visible = True;
			Items.DecorationSavePicture.Visible = False;
			Items.DecorationClearPicture.Visible = False;
			Items.DecorationRightPicture.Visible = False;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	GetMainPicture();
	Updatedialog();
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	FormsAtServer.BeforeWriteAtServer(ThisForm, Cancel, CurrentObject, WriteParameters);	
	
	WriteUnitsOfMeasure(CurrentObject);

	CurrentObject.SalesUnitOfMeasure = CurrentObject.BaseUnitOfMeasure;
	CurrentObject.PurchaseUnitOfMeasure = CurrentObject.BaseUnitOfMeasure;
	
	WriteMainPicture(CurrentObject);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)

	Updatedialog();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	WritePrice(CurrentObject);
	WriteBarCodes(CurrentObject);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	If EventName = "BackgroundJobEnded" Then
		If JobStructure = Undefined Then
			Return;
		EndIf;
		ArrayTempStorage = GetFromTempStorage(JobStructure.StorageAddress);
		For Each TempStorage In ArrayTempStorage Do
			If TempStorage.FileRef = Object.MainPicture Then
				MainPictureAddressInTempStorage = PutToTempStorage(TempStorage.BinaryData);
				MainPictureFileName = TempStorage.FileName;
			EndIf;
		EndDo;
		//Items.GroupPictureSetting.Visible = Not MainPictureAddressInTempStorage = "";
		Items.GroupMainPicture.CurrentPage = Items.GroupBasePicture;
	Else
		NotificationProcessingAtServer(EventName, Parameter);
	EndIf;	
	If EventName = "ChangeFiles" Then
		GetMainPicture();
	EndIf;
EndProcedure

&AtServer
Procedure NotificationProcessingAtServer(EventName, Parameter)

	DocumentsFormAtServer.NotificationProcessingAtServer(ThisForm, EventName, Parameter);
EndProcedure

&AtClient
Procedure UpdateDialog() Export
	#If WebClient Then
		If NOT IsOpen() Then
			Return;
		EndIf;
	#EndIf
	
	Items.MainBarCode.InputHint = Object.MainBarCodeType;
	
	index = 1;
	While Not Items.Find("AdditionalBarCode_" + Format(Index, "NG=")) = Undefined Do
		Item = Items.Find("AdditionalBarCode_" + Format(Index, "NG="));
		If Item.ChoiceList.FindByValue(BarCodes[Index - 1].UnitOfMeasure) = Undefined Then
			Item.ChoiceList.Add(BarCodes[Index - 1].UnitOfMeasure);
		EndIf;
		Item.InputHint = BarCodes[index - 1].BarCodeType;
		Index = Index + 1;
	EndDo;
	
	//Items.GroupPictureSetting.Visible = Not MainPictureAddressInTempStorage = "";
	Index = 1;
	While Not Items.Find("HistoryPrice_" + Format(Index,"NG=")) = Undefined Do
		Items["HistoryPrice_" + Format(Index,"NG=")].Visible = Not Object.Ref.IsEmpty();
		Index = Index + 1;
	EndDo;
EndProcedure

#EndRegion

#Region Languages

&AtClient
Procedure OpenGroupLanguagesClick(Item)
	Items.GroupLanguages.Visible = Not Items.GroupLanguages.Visible;
	UpdateDialog();
EndProcedure
#EndRegion

#Region Price
&AtServer
Procedure WritePrice(CurrentObject)
	For Each RowPrice In CurrentPrice Do
		If RowPrice.ValuePrice = RowPrice.FirstPrice And RowPrice.UnitOfMeasure = RowPrice.FirstUnitOfMeasure Then
			Continue;
		EndIf;
		
		PriceRecord = InformationRegisters.SalesPrices.CreateRecordManager();
		PriceRecord.Period = CurrentDate();
		PriceRecord.Item = CurrentObject.Ref;
		PriceRecord.PriceType = RowPrice.TypePrice;
		PriceRecord.Price = RowPrice.ValuePrice;
		PriceRecord.UnitOfMeasure = RowPrice.UnitOfMeasure;
		PriceRecord.Write(True);
	EndDo;          
EndProcedure

&AtServer
Procedure AddPriceItems(ReadRegister = True, AdditionalStructure = Undefined)
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	             |	SalesPriceTypes.Ref,
	             |	ISNULL(SalesPricesSliceLast.Price, 0) AS Price,
	             |	SalesPricesSliceLast.UnitOfMeasure
	             |FROM
	             |	Catalog.SalesPriceTypes AS SalesPriceTypes
	             |		LEFT JOIN InformationRegister.SalesPrices.SliceLast(, ) AS SalesPricesSliceLast
	             |		ON (SalesPricesSliceLast.PriceType = SalesPriceTypes.Ref)
	             |			AND (SalesPricesSliceLast.Item = &ItemRef)
	             |WHERE
	             |	SalesPriceTypes.DeletionMark = FALSE
	             |
	             |ORDER BY
	             |	SalesPriceTypes.Code";
	Query.SetParameter("ItemRef", Object.Ref);
	Result = Query.Execute();
	Selection = Result.Select();
	
	If ReadRegister Then
		While Selection.Next() Do
			If Not AdditionalStructure = Undefined Then
				If Not Selection.Ref = AdditionalStructure.PriceType Then
					Continue;
				EndIf;
			EndIf;
			FindPriceRows = CurrentPrice.FindRows(New Structure("TypePrice",Selection.Ref));
			If FindPriceRows.Count() = 0 Then
				NewPriceRow = CurrentPrice.Add();	
			Else
				NewPriceRow = FindPriceRows[0];	
			EndIf;
			NewPriceRow.TypePrice = Selection.Ref;
			NewPriceRow.ValuePrice = Selection.Price;
			NewPriceRow.FirstPrice = Selection.Price;
			NewPriceRow.UnitOfMeasure = ?(ValueIsFilled(Selection.UnitOfMeasure), Selection.UnitOfMeasure, Object.BaseUnitOfMeasure);
			NewPriceRow.FirstUnitOfMeasure = NewPriceRow.UnitOfMeasure;
			NewPriceRow.Currency = NewPriceRow.TypePrice.Currency;
			NewPriceRow.AmountType = NewPriceRow.TypePrice.AmountType;
			NewPriceRow.IsEmpty = Not ValueIsFilled(Selection.Price);
		EndDo;
	EndIf;

	IndexPrice = 1;
	Selection.Reset();
	While Selection.Next() Do
		If Not AdditionalStructure = Undefined Then
			If Not Selection.Ref = AdditionalStructure.PriceType Then
				IndexPrice = IndexPrice + 1;
				Continue;
			EndIf;
		EndIf;
		NewGroupe = Items.Find("GroupePrice_" + Format(IndexPrice, "NG="));
		If NewGroupe = Undefined Then
			NewGroupe = Items.Add("GroupePrice_" + Format(IndexPrice, "NG="), Type("FormGroup"), Items.GroupPrice);
		EndIf;
		NewGroupe.Type = FormGroupType.UsualGroup;
		NewGroupe.ShowTitle = False;
		NewGroupe.Representation = UsualGroupRepresentation.None;
		NewGroupe.Group = ChildFormItemsGroup.Horizontal;
		NewGroupe.ChildItemsVerticalAlign = ItemVerticalAlign.Center;
		
		NewPriceAttribute = Items.Find("ValuePrice_" + Format(IndexPrice, "NG="));
		If NewPriceAttribute = Undefined Then
			NewPriceAttribute = Items.Add("ValuePrice_" + Format(IndexPrice, "NG="), Type("FormField"), NewGroupe);
			NewPriceAttribute.DataPath = "CurrentPrice[" + Format(IndexPrice - 1, "NG=") + "].ValuePrice";
		EndIf;
		NewPriceAttribute.TitleLocation = FormItemTitleLocation.Auto;
		NewPriceAttribute.Title = String(CurrentPrice[IndexPrice - 1].TypePrice);// + " (" + CurrentPrice[IndexPrice - 1].TypePrice.Currency + ", " + CurrentPrice[IndexPrice - 1].TypePrice.AmountType + ")";
		NewPriceAttribute.Type = FormFieldType.InputField;
		NewPriceAttribute.ReadOnly = False;
		NewPriceAttribute.HorizontalStretch = False;
		NewPriceAttribute.AutoMaxWidth = False;
		NewPriceAttribute.Width = 10;
		
		NewUMAttributePic = Items.Find("HistoryPrice_" + Format(IndexPrice, "NG="));
		If NewUMAttributePic = Undefined Then
			NewUMAttributePic = Items.Add("HistoryPrice_" + Format(IndexPrice, "NG="), Type("FormDecoration"), NewGroupe);
		EndIf;
 		NewUMAttributePic.Type = FormDecorationType.Picture;
		NewUMAttributePic.Hyperlink = True;
		NewUMAttributePic.Picture = PictureLib.History_mon_16;
		NewUMAttributePic.ToolTip = Nstr("en='History...';pl='Historia...';ru='История...'");
		NewUMAttributePic.SetAction("Click", "OpenPriceHistory");
		
		NewPriceAttribute = Items.Find("CurrencyPrice_" + Format(IndexPrice, "NG="));
		If NewPriceAttribute = Undefined Then
			NewPriceAttribute = Items.Add("CurrencyPrice_" + Format(IndexPrice, "NG="), Type("FormDecoration"), NewGroupe);
		EndIf;
		NewPriceAttribute.Title = TrimAll(String(CurrentPrice[IndexPrice - 1].Currency) + " ");
		
		NewPriceAttribute = Items.Find("AmountTypePrice_" + Format(IndexPrice, "NG="));
		If NewPriceAttribute = Undefined Then
			NewPriceAttribute = Items.Add("AmountTypePrice_" + Format(IndexPrice, "NG="), Type("FormDecoration"), NewGroupe);
		EndIf;
		NewPriceAttribute.Title = TrimAll(String(CurrentPrice[IndexPrice - 1].AmountType)) + NStr("en=' for';pl=' za';ru=' для'");
		
		NewPriceAttribute = Items.Find("UnitOfMeasurePrice_" + Format(IndexPrice, "NG="));
		If NewPriceAttribute = Undefined Then
			NewPriceAttribute = Items.Add("UnitOfMeasurePrice_" + Format(IndexPrice, "NG="), Type("FormDecoration"), NewGroupe);
		EndIf;
		NewPriceAttribute.Title = String(CurrentPrice[IndexPrice - 1].UnitOfMeasure);
		NewPriceAttribute.Hyperlink = True;
		NewPriceAttribute.SetAction("Click", "ChangeUMPrice");
		
		IndexPrice = IndexPrice + 1;
	EndDo;
EndProcedure

&AtServer
Function GetItemSalesPricePromotions(Item, Customer = Undefined, Date = Undefined, ActiveOnly = True) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	SalesPricePromotions.Ref
	             |INTO PricePromotionsList
	             |FROM
	             |	(SELECT
	             |		SalesPricePromotions.Ref AS Ref
	             |	FROM
	             |		Catalog.SalesPricePromotions AS SalesPricePromotions
	             |	WHERE
	             |		SalesPricePromotions.PeriodFrom <= &Date
	             |		AND SalesPricePromotions.PeriodTo >= &Date
	             |		AND (NOT SalesPricePromotions.UseRestriction)
	             |	
	             |	UNION ALL
	             |	
	             |	SELECT
	             |		SalesPricePromotionsDiscountGroups.Ref
	             |	FROM
	             |		Catalog.SalesPricePromotions.DiscountGroups AS SalesPricePromotionsDiscountGroups
	             |	WHERE
	             |		SalesPricePromotionsDiscountGroups.Ref.PeriodFrom <= &Date
	             |		AND SalesPricePromotionsDiscountGroups.Ref.PeriodTo >= &Date
	             |		AND SalesPricePromotionsDiscountGroups.DiscountGroup = &DiscountGroup
	             |	
	             |	UNION ALL
	             |	
	             |	SELECT
	             |		SalesPricePromotionsCustomers.Ref
	             |	FROM
	             |		Catalog.SalesPricePromotions.Customers AS SalesPricePromotionsCustomers
	             |	WHERE
	             |		SalesPricePromotionsCustomers.Ref.PeriodFrom <= &Date
	             |		AND SalesPricePromotionsCustomers.Ref.PeriodTo >= &Date
	             |		AND SalesPricePromotionsCustomers.Customer = &Customer) AS SalesPricePromotions
	             |
	             |GROUP BY
	             |	SalesPricePromotions.Ref
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	PricePromotionsList.Ref AS Promotion,
	             |	PricePromotionsList.Ref.PeriodFrom AS PeriodFrom,
	             |	PricePromotionsList.Ref.PeriodTo AS PeriodTo,
	             |	SalesPricePromotions.Price,
	             |	PricePromotionsList.Ref.Currency AS Currency,
	             |	PricePromotionsList.Ref.AmountType AS AmountType,
	             |	SalesPricePromotions.UnitOfMeasure,
	             |	ISNULL(ExchangeRatesSliceLastInitial.ExchangeRate, 0) AS InitialExchangeRate,
	             |	ItemsUnitsOfMeasureInitial.Quantity AS InitialUoMQuantity
	             |FROM
	             |	PricePromotionsList AS PricePromotionsList
	             |		INNER JOIN InformationRegister.SalesPricePromotions AS SalesPricePromotions
	             |			LEFT JOIN Catalog.Items.UnitsOfMeasure AS ItemsUnitsOfMeasureInitial
	             |			ON SalesPricePromotions.Item = ItemsUnitsOfMeasureInitial.Ref
	             |				AND SalesPricePromotions.UnitOfMeasure = ItemsUnitsOfMeasureInitial.UnitOfMeasure
	             |		ON PricePromotionsList.Ref = SalesPricePromotions.Promotion
	             |			AND (SalesPricePromotions.Item = &Item)
	             |		LEFT JOIN InformationRegister.CurrencyExchangeRates.SliceLast(&Date, ) AS ExchangeRatesSliceLastInitial
	             |		ON PricePromotionsList.Ref.Currency = ExchangeRatesSliceLastInitial.Currency
	             |
	             |ORDER BY
	             |	PeriodFrom";
	
	Query.SetParameter("Item", Item);
	Query.SetParameter("Date", ?(Date = Undefined, BegOfDay(GetServerDate()), BegOfDay(Date)));
	
	If Customer = Undefined Then
		Query.Text = StrReplace(Query.Text, "AND SalesPricePromotionsDiscountGroups.DiscountGroup = &DiscountGroup", "");
		Query.Text = StrReplace(Query.Text, "AND SalesPricePromotionsCustomers.Customer = &Customer", "");
	Else
		Query.SetParameter("DiscountGroup", Customer.DiscountGroup);
		Query.SetParameter("Customer", Customer);
	EndIf;
	
	Return Query.ExecuteBatch()[1];
	
EndFunction

&AtServer
Procedure ReadPricePromotions(ActiveOnly = True)
	
	PricePromotions.Clear();
	
	Selection = GetItemSalesPricePromotions(Object.Ref, , CurrentDate(), ActiveOnly).Select();
	While Selection.Next() Do
		
		PricePromotionsRow = PricePromotions.Add();
		FillPropertyValues(PricePromotionsRow, Selection);
		
	EndDo;
	
	Items.GroupPricePromotions.Visible = Not PricePromotions.Count() = 0;
	
EndProcedure

&AtClient
Procedure ChangeUMPrice(Item)
	UMList = New ValueList;
	For Each RowUM In Object.UnitsOfMeasure Do
		If UMList.FindByValue(RowUM.UnitOfMeasure) = Undefined Then
			UMList.Add(RowUM.UnitOfMeasure);
		EndIf;
	EndDo;
	
	LinePrice = Number(StrReplace(Item.Name, "UnitOfMeasurePrice_", ""));
	
	NotifyDescr	= New NotifyDescription("ChangeUMPriceEnd", ThisForm, New Structure("LinePrice", LinePrice));
	ThisForm.ShowChooseFromList(NotifyDescr, UMList, Item, UMList.FindByValue(CurrentPrice[LinePrice - 1].UnitOfMeasure));
EndProcedure

&AtClient
Procedure ChangeUMPriceEnd(SelectedValue, QueryParameters) Export
	LinePrice	= QueryParameters.LinePrice;
	
	If Not SelectedValue = Undefined And ValueIsFilled(SelectedValue.Value) Then
		If Not CurrentPrice[LinePrice - 1].UnitOfMeasure = SelectedValue.Value Then
			CurrentPrice[LinePrice - 1].IsEmpty = False;
		EndIf;
		CurrentPrice[LinePrice - 1].UnitOfMeasure = SelectedValue.Value;
		Modified = True;
		Items["UnitOfMeasurePrice_" + Format(LinePrice, "NG=")].Title = TrimAll(String(CurrentPrice[LinePrice - 1].UnitOfMeasure));
	EndIf;
EndProcedure

&AtClient
Procedure OpenPriceHistory(Item)
	LinePrice = Number(StrReplace(Item.Name, "HistoryPrice_", ""));
	PriceType = CurrentPrice[LinePrice - 1].TypePrice;
	
	FilterStructure = New Structure("Item, PriceType", Object.Ref, PriceType);
	
	Notify = New NotifyDescription(
		"ChangePricesInRegister",
		ThisForm, 
		New Structure("Filter", FilterStructure));
	Items["ValuePrice_" + Format(LinePrice, "NG=")].ReadOnly = True;
	Items["UnitOfMeasurePrice_" + Format(LinePrice, "NG=")].Hyperlink = False;
	OpenForm("InformationRegister.SalesPrices.ListForm", New Structure("Filter", FilterStructure), ThisForm, String(Object.Ref.UUID()) + String(PriceType.UUID()),,, Notify);
EndProcedure

&AtClient
Procedure ChangePricesInRegister(MainParameters, AdditionalParameters) Export
	AddPriceItems(True, AdditionalParameters.Filter);
	UpdateDialog();
EndProcedure
#EndRegion

#Region BarCodes
&AtServer
Procedure WriteBarCodes(CurrentObject)
	Records = InformationRegisters.BarCodes.CreateRecordSet();
	Records.Filter.Object.Value = CurrentObject.Ref;
	Records.Filter.Object.Use = True;
	Records.Read();
	Records.Clear();
	For Each RowBarCoder In BarCodes Do
		If RowBarCoder.BarCode = "" Then
			Continue;
		EndIf;
		NewRecord = Records.Add();
		NewRecord.BarCode = RowBarCoder.BarCode;
		NewRecord.Object = CurrentObject.Ref;
		NewRecord.BarCodeType = RowBarCoder.BarCodeType;
		NewRecord.UnitOfMeasure = RowBarCoder.UnitOfMeasure;
	EndDo;
	Records.Write = True;
	Records.Write(True);
EndProcedure

&AtClient
Procedure BarCodeStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	NotifyDescr	= New NotifyDescription("BarCodeStartChoiceEnd", ThisForm, New Structure("Item", Item));
	
	If Item.Name = "MainBarCode" Then
		InitialValue = TypeBarCodeList.FindByValue(Object.MainBarCodeType);
	Else
		InitialValue = TypeBarCodeList.FindByValue(BarCodes[Number(StrReplace(Item.Name, "AdditionalBarCode_", "")) - 1].BarCodeType);
	EndIf;
	
	ThisForm.ShowChooseFromList(NotifyDescr, TypeBarCodeList, Item, InitialValue);
EndProcedure

&AtClient
Procedure BarCodeStartChoiceEnd(SelectedValue, QueryParameters) Export 
	Item	= QueryParameters.Item;
	
	If Not SelectedValue = Undefined And ValueIsFilled(SelectedValue.Value) Then
		If Item.Name = "MainBarCode" Then
			Object.MainBarCodeType = SelectedValue.Value;
		Else
			BarCodes[Number(StrReplace(Item.Name, "AdditionalBarCode_", "")) - 1].BarCodeType = SelectedValue.Value;
		EndIf;
		UpdateDialog();
	EndIf;	
EndProcedure

&AtServer
Procedure ReadBarCodes()	
	If Not ValueIsFilled(Object.MainBarCodeType) Then
		Object.MainBarCodeType = Catalogs.BarCodeTypes.EAN13;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	BarCodeTypes.Ref
	             |FROM
	             |	Catalog.BarCodeTypes AS BarCodeTypes
	             |WHERE
	             |	BarCodeTypes.DeletionMark = FALSE";
	
	Result = Query.Execute();
	Selection = Result.Select();
	TypeBarCodeList = New ValueList;
	While Selection.Next() Do
	
		TypeBarCodeList.Add(Selection.Ref);
	
	EndDo;
	
	BarCodes.Clear();
	
	Query = New Query;
	Query.Text = "SELECT
	|	BarCodes.BarCode,
	|	BarCodes.BarCodeType,
	|	BarCodes.UnitOfMeasure
	|FROM
	|	InformationRegister.BarCodes AS BarCodes
	|WHERE
	|	BarCodes.Object = &Ref";

	Query.SetParameter("Ref", Object.Ref);

	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		RowBarCode = BarCodes.Add(); 
		RowBarCode.BarCode = Selection.BarCode;
		RowBarCode.BarCodeType = Selection.BarCodeType;
		RowBarCode.UnitOfMeasure = Selection.UnitOfMeasure;
	EndDo;
EndProcedure	
#EndRegion

#Region UnitOfMeasure
&AtServer
Procedure OrderedUnitOfMeasure(ObjectItem)
	UnitsOfMeasureTable = ObjectItem.UnitsOfMeasure.Unload();
	UnitsOfMeasureTable.Columns.Add("IsBaseUM");
	
	For Each RowUnitsOfMeasure In UnitsOfMeasureTable Do
		RowUnitsOfMeasure.IsBaseUM = (RowUnitsOfMeasure.UnitOfMeasure = ObjectItem.BaseUnitOfMeasure);
	EndDo;
	
	UnitsOfMeasureTable.Sort("IsBaseUM desc");
	ObjectItem.UnitsOfMeasure.Load(UnitsOfMeasureTable);
EndProcedure

&AtServer
Procedure WriteUnitsOfMeasure(CurrentObject)
	
	OrderedUnitOfMeasure(CurrentObject);
	
	RowsBaseUnitOfMeasure = CurrentObject.UnitsOfMeasure.FindRows(New Structure("Quantity", 1));
	If RowsBaseUnitOfMeasure.Count() = 0 Then
		RowBaseUnitOfMeasure = CurrentObject.UnitsOfMeasure.Add();
	Else
		RowBaseUnitOfMeasure = RowsBaseUnitOfMeasure[0];
	EndIf;
	RowBaseUnitOfMeasure.UnitOfMeasure = CurrentObject.BaseUnitOfMeasure;
	RowBaseUnitOfMeasure.Quantity = 1;
EndProcedure

&AtServer
Procedure ReadUnitsOfMeasure()
	If Object.Ref.IsEmpty() Then
		If Not ValueIsFilled(Object.BaseUnitOfMeasure) Then
			Object.BaseUnitOfMeasure = Constants.BaseUnitOfMeasure.Get();
		EndIf;
	
		BaseUnitOfMeasureRows = Object.UnitsOfMeasure.FindRows(New Structure("Quantity", 1));
		If BaseUnitOfMeasureRows.Count() = 0 Then
			NewRow = Object.UnitsOfMeasure.Add();
		Else
			NewRow = BaseUnitOfMeasureRows[0];
		EndIf;
		NewRow.UnitOfMeasure = Object.BaseUnitOfMeasure;
		NewRow.Quantity = 1;
	EndIf;
	AddUnitsOfMeasureItems();
EndProcedure	

&AtServer
Procedure AddUnitsOfMeasureItems() Export
	For Each RowUnitOfMeasure In Object.UnitsOfMeasure Do
		If RowUnitOfMeasure.Quantity = 1 And RowUnitOfMeasure.UnitOfMeasure = Object.BaseUnitOfMeasure Then
			Continue;
		EndIf;
		If Not Items.Find("UnitOfMeasure_" + Format(RowUnitOfMeasure.LineNumber, "NG=")) = Undefined Then
			Continue;
		EndIf;
		
		NewGroupe = Items.Add("GroupUnitOfMeasure_" + Format(RowUnitOfMeasure.LineNumber, "NG="), Type("FormGroup"), Items.GroupAdditionalsUnitsOfMeasure);
		NewGroupe.Type = FormGroupType.UsualGroup;
		NewGroupe.ShowTitle = False;
		NewGroupe.VerticalAlignInGroup = ItemVerticalAlign.Center;
		NewGroupe.Representation = UsualGroupRepresentation.None;
		NewGroupe.Group = ChildFormItemsGroup.Horizontal;
		NewGroupe.HorizontalStretch = False;
		
		NewUMAttribute = Items.Add("UnitOfMeasure_" + Format(RowUnitOfMeasure.LineNumber, "NG="), Type("FormField"), NewGroupe);
		NewUMAttribute.Type = FormFieldType.InputField;
		NewUMAttribute.SetAction("Opening", "BaseUnitOfMeasureOpening");
		NewUMAttribute.DataPath = "Object.UnitsOfMeasure[" + Format(RowUnitOfMeasure.LineNumber - 1, "NZ=0; NG=") + "].UnitOfMeasure";
		NewUMAttribute.Width = 10;
		NewUMAttribute.HorizontalStretch = False;
		NewUMAttribute.Title = NStr("en='Additional u.m.';pl='Dodatkowa j.m.';ru='Дополнительная ед. изм.'");
		NewUMAttribute.TitleLocation = FormItemTitleLocation.Auto;
		
		NewUMAttributePic = Items.Add("DeleteUnitsOfMeasure_" + Format(RowUnitOfMeasure.LineNumber, "NG="), Type("FormDecoration"), NewGroupe);
 		NewUMAttributePic.Type = FormDecorationType.Picture;
		NewUMAttributePic.Hyperlink = True;
		NewUMAttributePic.Picture = PictureLib.Minus_mon_16;
		NewUMAttributePic.SetAction("Click", "DeleteUM");

	EndDo;
EndProcedure

&AtServer
Procedure DeleteUMAtServer(Val ItemName = "") Export
	If Not ItemName = "" Then
		Item = Items[ItemName];
		LineNumber = Number(StrReplace(ItemName, "DeleteUnitsOfMeasure_", ""));
		Object.UnitsOfMeasure.Delete(LineNumber - 1);
	EndIf;
	q = 2;
	While Not Items.Find("GroupUnitOfMeasure_" + Format(q, "NG=")) = Undefined Do
		ItemGruop = Items.Find("GroupUnitOfMeasure_" + Format(q, "NG="));
		LineNumber = Number(StrReplace(ItemGruop.Name, "GroupUnitOfMeasure_", ""));
		
		ItemsForDelete = New Array;
		For Each DelItem In ItemGruop.ChildItems Do
			Items.Delete(DelItem);
		EndDo;
		Items.Delete(ItemGruop);
		q = q + 1;
	EndDo;
	AddUnitsOfMeasureItems();
EndProcedure	

&AtClient
Procedure DeleteUM(Item)
	Modified	= True;
	
	QueryText	= NStr("en='Remove unit?';pl='Usunąć jednostkę?';ru='Удалить единицу измерения?'");
	Mode		= QuestionDialogMode.YesNo;
	QueryParams	= New Structure("Name", Item.Name);
	Notify		= New NotifyDescription("AfterQueryBoxDeleteUM", ThisObject, QueryParams);
	
	ShowQueryBox(Notify, QueryText, Mode);

EndProcedure

&AtClient
Procedure AfterQueryBoxDeleteUM(Answer, Parameters) Export 
	If Answer = DialogReturnCode.Yes Then
		DeleteUMAtServer(Parameters.Name);
	EndIf;	
EndProcedure

&AtClient
Procedure OpenBarCodeForm()
	OpenForm("Catalog.Items.Form.BarCodeForm", , ThisForm);
EndProcedure

&AtClient
Procedure BaseUnitOfMeasureOnChange(Item)
	FindRows = Object.UnitsOfMeasure.FindRows(New Structure("Quantity", 1));
	If FindRows.Count() = 0 Then
		Return;
	EndIf;
	FindRows[0].UnitOfMeasure = Object.BaseUnitOfMeasure;
	
	If Object.Ref.IsEmpty() Then
		Index = 1;
		For Each RowPrice In CurrentPrice Do
			If Not RowPrice.IsEmpty Then
				Continue;
			EndIf;
			RowPrice.UnitOfMeasure = Object.BaseUnitOfMeasure;
			
			ItemPriceUM = Items["UnitOfMeasurePrice_" + Format(Index, "NG=")];
			ItemPriceUM.Title = String(CurrentPrice[Index - 1].UnitOfMeasure);
			Index = Index + 1;
		EndDo;
	EndIf;
EndProcedure

&AtClient
Procedure BaseUnitOfMeasureOpening(Item, StandardProcessing, NewRow = False)
	StandardProcessing = False;
	If Item.Name = "BaseUnitOfMeasure" Then
		FindRows = Object.UnitsOfMeasure.FindRows(New Structure("UnitOfMeasure", Object["BaseUnitOfMeasure"]));
		If FindRows.Count() = 0 Then
			NewLine = Object.UnitsOfMeasure.Add();
			LineNumber = NewLine.LineNumber;
		Else
			LineNumber = FindRows[0].LineNumber;
		EndIf;
	Else
		LineNumber = Number(StrReplace(Item.Name, "UnitOfMeasure_", ""));
	EndIf;
	
	BarCodeStructure = New Structure();
	
	CurrentUnitOfMeasure = Object.UnitsOfMeasure[LineNumber - 1].UnitOfMeasure;
	Index = 1;
	For Each RowBarCodes In BarCodes Do
		If RowBarCodes.UnitOfMeasure = CurrentUnitOfMeasure Then
			BarCodeStructure.Insert("Row_" + Format(Index, "NG="), New Structure("BarCodeType, BarCode, UnitOfMeasure", RowBarCodes.BarCodeType, RowBarCodes.BarCode, CurrentUnitOfMeasure));
			Index = Index + 1;
		EndIf;
	EndDo;
	OpenForm("Catalog.Items.Form.UnitOfMeasureRow", New Structure("LineNumber, NewRow, BarCodeStructure", LineNumber - 1, NewRow, BarCodeStructure), ThisForm);
EndProcedure

&AtClient
Procedure AddNewUnitsOfMeasureClick(Item)
	Modified = True;
	NewLine = Object.UnitsOfMeasure.Add();
	AddUnitsOfMeasureItems();
	BaseUnitOfMeasureOpening(Items["UnitOfMeasure_" + Format(NewLine.LineNumber, "NG=")], False, True);
EndProcedure

#EndRegion

#Region Picture
&AtServer
Procedure WriteMainPicture(CurrentObject)
	If ValueIsFilled(MainPictureAddressInTempStorage) Then
		If ValueIsFilled(Object.MainPicture) Then
			ObjectFiles = Object.MainPicture.GetObject();
		Else
			ObjectFiles = Catalogs.Files.CreateItem();
		EndIf;
		ObjectFiles.RefObject = Object.Ref;
		ObjectFiles.Description = MainPictureFileName;
		If TrimAll(ObjectFiles.Link) = "" Then
			ObjectFiles.Data = New ValueStorage(GetFromTempStorage(MainPictureAddressInTempStorage));
		Else
			ObjectFiles.Data = New ValueStorage(Undefined);
		EndIf;
		ObjectFiles.Write();
		CurrentObject.MainPicture = ObjectFiles.Ref;
	ElsIf Not ValueIsFilled(MainPictureAddressInTempStorage) And ValueIsFilled(Object.MainPicture) Then
		ObjectFiles = Object.MainPicture.GetObject();
		ObjectFiles.Description = "";
		ObjectFiles.RefObject = Undefined;
		ObjectFiles.DeletionMark = True;
		ObjectFiles.Data = New ValueStorage(Undefined);
		Object.MainPicture = Catalogs.Files.EmptyRef();
		ObjectFiles.Write();
	EndIf;
EndProcedure

&AtClient
Procedure GetMainPicture() Export
	If ValueIsFilled(Object.MainPicture) Then
		Items.DecorationRightPicture.Visible = True;
		Items.DecorationClearPicture.Visible = True;
		Items.DecorationSavePicture.Visible = True;
		Items.GroupMainPicture.CurrentPage = Items.GroupLoadPicture;
	    JobStructure = GetMainPictureAtServer();
		JobAfterStart();
	Else
		Items.DecorationRightPicture.Visible = False;
		Items.DecorationClearPicture.Visible = False;
		Items.DecorationSavePicture.Visible = False;
	EndIf;
EndProcedure

&AtServer
Function GetMainPictureAtServer() 

	PicturesArray = New Array;
	PicturesArray.Add(Object.MainPicture);
	
	JobParameters = New Structure("FilesArray, FormUUID", PicturesArray, UUID);
	Return LongActionsServer.ExecuteInBackground(UUID, "Catalogs.Files.GetTempStorage", JobParameters);
EndFunction

&AtClient
Procedure JobAfterStart()
	
	AttachIdleHandler("IdleHandlerForJob", 0.1, True);
	
EndProcedure	

&AtClient
Procedure IdleHandlerForJob()
	
	If LongActionsServer.JobCompleted(JobStructure.JobID) Then
		DetachIdleHandler("IdleHandlerForJob");
		Notify("BackgroundJobEnded", New Structure("Name, ResultAddress", JobStructure.ProcedureName, JobStructure.StorageAddress));
		Return;
	EndIf;
			
	AttachIdleHandler("IdleHandlerForJob", 0.1, True);
	
EndProcedure	

&AtClient
Procedure MainPictureClick(Item, StandardProcessing)
	StandardProcessing = False;
	BeginPutFile(New NotifyDescription("EndPutFile", ThisForm),,,,UUID);
	UpdateDialog();
EndProcedure

&AtClient
Procedure DecorationSavePictureClick(Item)
	If IsTempStorageURL(MainPictureAddressInTempStorage) Then
		GetFile(MainPictureAddressInTempStorage,MainPictureFileName,True);
	EndIf;
	UpdateDialog();
EndProcedure

&AtServer
Procedure DeletePicture(Picture)
	PictureObject = Picture.GetObject();
	PictureObject.SetDeletionMark(True);
	PictureObject.Write();
	ChangePicAtServer(1);
EndProcedure
	
&AtClient
Procedure DecorationClearPictureClick(Item)
	If IsTempStorageURL(MainPictureAddressInTempStorage) Then
		DeleteFromTempStorage(MainPictureAddressInTempStorage);
		MainPictureAddressInTempStorage = "";
		Modified = True;
	EndIf;
	If ValueIsFilled(Object.MainPicture) Then
		DeletePicture(Object.MainPicture);
		ChangePicAtServer(-1);
		GetMainPicture();
	EndIf;
	UpdateDialog();
EndProcedure

#EndRegion

&AtClient
Procedure ParentOnChange(Item)
	If ValueIsFilled(Object.Parent) Then
		DifferentAttributes = ParentOnChangeAtServer();
		If DifferentAttributes.Count() > 0 Then
			EndParentOnChange = New NotifyDescription("EndParentOnChange", ThisForm, DifferentAttributes);
			ShowQueryBox(EndParentOnChange, NStr("ru='Заполнить значения атрибутов из выбранной группы?'; pl='Czy wypełnić wartości atrybutów z wybranej grupy?';en='Fill attributes from the selected group?'"), QuestionDialogMode.YesNo);
		EndIf;
		UpdateDialog();
	EndIf;
EndProcedure

&AtClient
Procedure EndParentOnChange(QuestionAnswer, DifferentAttributes) Export 
	If QuestionAnswer = DialogReturnCode.Yes Then
		For Each Attribute In DifferentAttributes Do
			Object[Attribute.Key] = Attribute.Value.NewValue;
			If Attribute.Key = "BaseUnitOfMeasure" Then
				BaseUnitOfMeasureOnChange(Undefined);
			EndIf;
		EndDo;
	EndIf;
EndProcedure

&AtServer
Function ParentOnChangeAtServer()

	DifferentAttributes = New Structure;
	
	AttributesFromParent = New Array;
	
	AttributesFromParent.Add("BaseUnitOfMeasure");
	AttributesFromParent.Add("PurchaseUnitOfMeasure");
	AttributesFromParent.Add("SalesUnitOfMeasure");
	AttributesFromParent.Add("AccountingGroup");
	AttributesFromParent.Add("SalesPriceGroup");
	AttributesFromParent.Add("MainBarCodeType");
	AttributesFromParent.Add("OriginCountry");
	AttributesFromParent.Add("CustomDuty");
	AttributesFromParent.Add("SupplementaryUnitOfMeasure");
	AttributesFromParent.Add("BaseSupplier");
	AttributesFromParent.Add("Vendor");
	AttributesFromParent.Add("OriginCountry");
	AttributesFromParent.Add("IntrastatCNCode");
	AttributesFromParent.Add("IntrastatCNDescription");

	For Each AttributeParent In AttributesFromParent Do
		If Not Object[AttributeParent] = Object.Parent[AttributeParent] Then
			DifferentAttributes.Insert(AttributeParent, New Structure("CurrentValue, NewValue", Object[AttributeParent], Object.Parent[AttributeParent]));
		EndIf;
	EndDo;
	
	Return DifferentAttributes;
	
EndFunction

&AtServer
Function WriteNewFile()
	ObjectFiles = Catalogs.Files.CreateItem();
	ObjectFiles.RefObject = Object.Ref;
	ObjectFiles.Description = MainPictureFileName;
	If TrimAll(ObjectFiles.Link) = "" Then
		ObjectFiles.Data = New ValueStorage(GetFromTempStorage(MainPictureAddressInTempStorage));
	Else
		ObjectFiles.Data = New ValueStorage(Undefined);
	EndIf;
	ObjectFiles.Write();
	Return ObjectFiles.Ref;
EndFunction

&AtClient
Procedure EndPutFile(FileIsSending, PictureAddressInTempStorage, Val FileName, AdditionalParameters) Export 
	If FileName = Undefined Then
		Return;
	EndIf;
	If IsTempStorageURL(MainPictureAddressInTempStorage) Then
		LoadFromFile = False;
		DeleteFromTempStorage(MainPictureAddressInTempStorage);
		MainPictureAddressInTempStorage = "";
	EndIf;
	If FileIsSending Then
		MainPictureAddressInTempStorage = PictureAddressInTempStorage;
		While Find(FileName, "\") > 0 Do
			FileName = Mid(FileName, Find(FileName, "\")+1);
		EndDo;
		MainPictureFileName = FileName;
		If Not Object.Ref.IsEmpty() Then
			Object.MainPicture = WriteNewFile();
			
		EndIf;
		Modified = True;
	EndIf;
	UpdateDialog();
EndProcedure

&AtServer
Procedure ChangePicAtServer(IndexMove)
	Pictures = New Array;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	Files.Ref
	             |FROM
	             |	Catalog.Files AS Files
	             |WHERE
	             |	Files.DeletionMark = FALSE
	             |	AND Files.RefObject = &RefObject
	             |
	             |ORDER BY
	             |	Files.Code";
	
	Query.SetParameter("RefObject", Object.Ref);
	
	Result = Query.Execute();
	Selection = Result.Select();
	CurrentPictureIndex = 0;
	IndexSelection = 0;
	NextPicture = Undefined;
	While Selection.Next() Do
	
		Pictures.Add(Selection.Ref);
		If Selection.Ref = Object.MainPicture Then
			CurrentPictureIndex = IndexSelection;
		EndIf;
		IndexSelection = IndexSelection + 1;
	EndDo;
	
	If NextPicture = Undefined And Pictures.Count() > 0 Then
		If Not ValueIsFilled(Object.MainPicture) OR CurrentPictureIndex + IndexMove < 0 Then
			NextPicture = Pictures[Pictures.Count() - 1];
		ElsIf Pictures.Count() <= CurrentPictureIndex + IndexMove Then
			Object.MainPicture = Undefined;
			MainPictureAddressInTempStorage = "";
		Else
			NextPicture = Pictures[CurrentPictureIndex + IndexMove];
		EndIf;
	EndIf;
	Object.MainPicture = NextPicture;
EndProcedure 

&AtClient
Procedure DecorationLeftPictureClick(Item)
	ChangePicAtServer(-1);
	GetMainPicture();
EndProcedure

&AtClient
Procedure DecorationRightPictureClick(Item)
	ChangePicAtServer(1);
	GetMainPicture();
EndProcedure
