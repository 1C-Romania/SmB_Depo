////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// The function returns the file data
//
&AtServerNoContext
Function GetFileData(PictureFile, UUID)
	
	Return AttachedFiles.GetFileData(PictureFile, UUID);
	
EndFunction // GetFileData()

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Sets the corresponding value for the GenerateDescriptionFullAutomatically variable.
//
//
&AtClientAtServerNoContext
Function SetFlagToFormDescriptionFullAutomatically(Description, DescriptionFull)
	
	Return (Description = DescriptionFull OR IsBlankString(DescriptionFull));
	
EndFunction // SetFlagToFormFullDescriptionAutomatically()

// Prepare the record structure for the basic sale prices
//
&AtServer
Function GetMainSalesPriceFillData()
	
	FillingData = New Structure;
	FillingData.Insert("Period", CurrentSessionDate());
	FillingData.Insert("PriceKind", PriceKind);
	FillingData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
	FillingData.Insert("Price", MainSalePrice);
	FillingData.Insert("ProductsAndServices", Object.Ref);
	FillingData.Insert("MeasurementUnit", Object.MeasurementUnit);
	
	Return FillingData; 
	
EndFunction // GetMainSalesPriceFillData()

// In case the basic sale price is changed, we make it basic at the item form
//
&AtServer
Procedure SetChangeBasicSalesPrice()
	
	If MainSalePrice <> 0 Then
		
		FillingData = GetMainSalesPriceFillData();
		
		If MainSalePrice <> Catalogs.ProductsAndServices.GetMainSalePrice(FillingData.PriceKind, FillingData.ProductsAndServices, FillingData.MeasurementUnit) Then
			
			InformationRegisters.ProductsAndServicesPrices.SetChangeBasicSalesPrice(FillingData);
			
		EndIf;
		
	EndIf;
	
EndProcedure // SetChangeBasicSalePrice()

// Fills in the attribute of the MainSalePrice form
//
&AtServer
Procedure FillBasicSalesPriceOnServer()
	
	MainSalePrice = Catalogs.ProductsAndServices.GetMainSalePrice(PriceKind, Object.Ref, Object.MeasurementUnit);
	
EndProcedure //FillBasicSalesPrice()

// The procedure initiates the BasicSalesPrice
// form attribute filling and updates the corresponding item of the form
//
&AtClient
Procedure InitiateFillingBasicSalesPriceOnClient()
	
	FillBasicSalesPriceOnServer();
	
	Items.MainSalePrice.UpdateEditText();
	
EndProcedure // FillFillBasicSalesPriceOnServer()

// Image view procedure
//
&AtClient
Procedure SeeAttachedFile()
	
	ClearMessages();
	
	If ValueIsFilled(Object.PictureFile) Then
		
		FileData = GetFileData(ThisForm.Object.PictureFile, UUID);
		AttachedFilesClient.OpenFile(FileData);
		
	Else
		
		MessageText = NStr("en='Picture for viewing is absent';ru='Отсутстует изображение для просмотра'");
		CommonUseClientServer.MessageToUser(MessageText,, "PictureURL");
		
	EndIf;
	
EndProcedure // ViewAttachedFile()

// Procedure of the image adding for the products and services
//
&AtClient
Procedure AddImageAtClient()
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en='To select the image it is necessary to record the object. Record?';ru='Для выбора изображения необходимо записать объект. Записать?'");
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("AddImageAtClientEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		AddImageAtClientFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageAtClientEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.Yes Then
        Write();
    Else 
        Return
    EndIf;
    
    
    AddImageAtClientFragment();

EndProcedure

&AtClient
Procedure AddImageAtClientFragment()
	
	Var FileID, Filter;
	
	If ValueIsFilled(Object.PictureFile) Then
		
		SeeAttachedFile();
		
	ElsIf ValueIsFilled(Object.Ref) Then
		
		InsertImagesFromProductsAndServices = True;
		FileID = New UUID;
		
		Filter = NStr("en = 'All Images (*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf)|*.bmp;*.gif;*.png;*.jpeg;*.dib;*.rle;*.tif;*.jpg;*.ico;*.wmf;*.emf"
		+ "|All files(*.*)|*.*"
		+ "|bmp format (*.bmp*;*.dib;*.rle)|*.bmp;*.dib;*.rle"
		+ "|GIF format (*.gif*)|*.gif"
		+ "|JPEG format (*.jpeg;*.jpg)|*.jpeg;*.jpg"
		+ "|PNG format (*.png*)|*.png"
		+ "|TIFF format (*.tif)|*.tif"
		+ "|icon format (*.ico)|*.ico"
		+ "|metafile format (*.wmf;*.emf)|*.wmf;*.emf'");
		
		AttachedFilesClient.AddFiles(Object.Ref, FileID, Filter);
		
	EndIf;
	
EndProcedure // AddImageAtClient()

// The function returns the file (image) data
//
&AtServerNoContext
Function URLImages(PictureFile, FormID)
	
	SetPrivilegedMode(True);
	Return AttachedFiles.GetFileData(PictureFile, FormID).FileBinaryDataRef;
	
EndFunction // ImageURL()

// Procedure opens the list of the image selection from already attached files
//
&AtClient
Procedure ChoosePictureFromAttachedFiles()
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("FileOwner", Object.Ref);
	ChoiceParameters.Insert("ChoiceMode", True);
	ChoiceParameters.Insert("CloseOnChoice", True);
	
	OpenForm("CommonForm.AttachedFiles", ChoiceParameters, ThisForm);
	
EndProcedure // SelectImageFromAttachedFiles()

&AtServer
Procedure FillAlcoholProductsAttributesByItemGroup()

	If Object.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.ProductsAndServicesCategory) Then
		Object.AlcoholicProductsKind = Undefined;
		Object.CountryOfOrigin = Undefined;
	EndIf;
	
	If Object.AlcoholicProductsKind <> Object.ProductsAndServicesCategory.AlcoholicProductsKind Then
		Object.AlcoholicProductsKind = Object.ProductsAndServicesCategory.AlcoholicProductsKind;
	EndIf;
	
	Object.ImportedAlcoholicProducts = Object.CountryOfOrigin <> Constants.HomeCountry.Get();
	If Object.ImportedAlcoholicProducts <> Object.ProductsAndServicesCategory.ImportedAlcoholicProducts Then
		Object.CountryOfOrigin = ?(Object.ProductsAndServicesCategory.ImportedAlcoholicProducts, Undefined, Constants.HomeCountry.Get());
	EndIf;

EndProcedure // FillAlcoholProductsAttributesByItemGroup()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

&AtServer
// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
Procedure SetVisibleAndEnabled(OnProductsAndServicesTypeChanged = False)
	
	Items.EstimationMethod.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
										OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
	Items.BusinessActivity.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
													OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
													OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service
													OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work, True, False);
	
	Items.Vendor.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
										OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
										OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service, True, False);
	
	Items.Warehouse.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
									OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
	Items.Specification.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
										OR (Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem AND Constants.FunctionalOptionUseSubsystemProduction.Get())
										OR (Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work AND Constants.FunctionalOptionUseWorkSubsystem.Get()), True, False);
	
	Items.ReplenishmentMethod.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
											OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
	Items.ReplenishmentDeadline.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
											OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
	Items.VATRate.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
										OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
										OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service
										OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work, True, False);
	
	Items.AlcoholicProductsKind.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
														OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
	Items.AlcoholicProductsManufacturerImporter.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
																		OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
	Items.GroupDecaliters.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
											OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
 //Items.EditGLAccounts.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
 //												OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
 //		 									 OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work
 //												OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Operation
 //                    OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service, True, False);
		
	Items.Cell.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
									OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
	Items.UseCharacteristics.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
														OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
														OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service
														OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work, True, False);
	
	Items.UseBatches.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
												OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
	
	Items.OrderCompletionDeadline.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
												OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
												OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service
												OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work, True, False);
	
	
	Items.TimeNorm.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
										OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Operation, True, False);
	
	Items.Picture.Visible = ?((NOT ValueIsFilled(Object.ProductsAndServicesType))
										OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem, True, False);
										
	Items.RadioButtonCalculationMethodValue.Visible = ?(Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work, True, False);
	
	Items.CountryOfOrigin.Visible	 = (Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem);
	
	ItemsVisible = (Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem);
	Элементы.UseSerialNumbers.Visible = ItemsVisible;
	Элементы.GuaranteePeriod.Visible = ItemsVisible;
	Элементы.WriteOutTheGuaranteeCard.Visible = ItemsVisible;
	
	If OnProductsAndServicesTypeChanged Then
		
		Object.ReplenishmentDeadline = 0;
		Object.UseCharacteristics = False;
		Object.UseBatches = False;
		Object.OrderCompletionDeadline = 0;
		Object.TimeNorm = 0;
		
		UseSubsystemProduction = Constants.FunctionalOptionUseSubsystemProduction.Get();
		
		If Items.EstimationMethod.Visible Then
			Object.EstimationMethod = Enums.InventoryValuationMethods.ByAverage;
		EndIf;
		
		If Items.BusinessActivity.Visible Then
			Object.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
		EndIf;
		
		If Items.Warehouse.Visible Then
			Object.Warehouse = Catalogs.StructuralUnits.MainWarehouse;
		EndIf;
		
		If Items.ReplenishmentMethod.Visible Then
			Object.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
		EndIf;
		
		If Not ValueIsFilled(Object.ProductsAndServicesType)
			OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem Then
			Object.InventoryGLAccount = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
		EndIf;
		
		If Not ValueIsFilled(Object.ProductsAndServicesType)
			OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
			OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work
			OR Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Operation Then
			If UseSubsystemProduction Then
				Object.ExpensesGLAccount = ChartsOfAccounts.Managerial.UnfinishedProduction;
			Else
				Object.ExpensesGLAccount = ChartsOfAccounts.Managerial.CommercialExpenses;
			EndIf;
		EndIf;
		
		If Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service Then
			Object.ExpensesGLAccount = ChartsOfAccounts.Managerial.CommercialExpenses;
		EndIf;
		
		If Items.ReplenishmentDeadline.Visible Then
			Object.ReplenishmentDeadline = 1;
		EndIf;
		
		If Items.OrderCompletionDeadline.Visible Then
			Object.OrderCompletionDeadline = 1;
		EndIf;
		
		If Items.VATRate.Visible Then
			Object.VATRate = Catalogs.Companies.MainCompany.DefaultVATRate;
		EndIf;
		
		If Object.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem Then
			Object.AlcoholicProductsKind = Undefined;
			Object.AlcoholicProductsManufacturerImporter = Undefined;
			Object.VolumeDAL = 0;
		EndIf;
		
	EndIf;
	
	// Prices
	Items.InformationAboutPrices.Visible = AccessRight("Read", Metadata.InformationRegisters.ProductsAndServicesPrices);
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	Items.MainSalePrice.ReadOnly = Not AllowedEditDocumentPrices;
	
EndProcedure // SetVisibleAndEnabled()

&AtServer
// Procedure sets the form attribute visible
// from the Use Production Subsystem options, Works.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionJobsSubsystem()
	
	// Production.
	If Constants.FunctionalOptionUseSubsystemProduction.Get() Then
		
		// Replenishment method.
		Items.ReplenishmentMethod.ChoiceList.Add(Enums.InventoryReplenishmentMethods.Production);
		
		// Warehouse. Setting the method of structural unit selection depending on FO.
		If Not Constants.FunctionalOptionAccountingByMultipleDepartments.Get()
			AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.Warehouse.ListChoiceMode = True;
			Items.Warehouse.ChoiceList.Add(Catalogs.StructuralUnits.MainWarehouse);
			Items.Warehouse.ChoiceList.Add(Catalogs.StructuralUnits.MainDepartment);
		
		EndIf;
		
	Else
		
		If Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.StructuralUnitsTypes.Warehouse);
			NewArray.Add(Enums.StructuralUnitsTypes.Retail);
			NewArray.Add(Enums.StructuralUnitsTypes.RetailAccrualAccounting);
			ArrayTypesOfStructuralUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfStructuralUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Items.Warehouse.ChoiceParameters = NewParameters;
			
		Else
			
			Items.Warehouse.Visible = False;
			
		EndIf;
		
	EndIf;
	
	// Reprocessing.
	If Constants.FunctionalOptionTransferRawMaterialsForProcessing.Get() Then
		Items.ReplenishmentMethod.ChoiceList.Add(Enums.InventoryReplenishmentMethods.Processing);
	EndIf;
	
EndProcedure // SetVisibleFromFOUseProductionWorkSubsystem()

// Procedure fills the list of the products and services types available for selection depending on the form parameters and functional options
// 
&AtServer
Procedure FillListTypes()
	
	List = Items.ProductsAndServicesType.ChoiceList;
	
	ProductAndServicesTypeRestriction = Undefined;
	If Not Parameters.FillingValues.Property("ProductsAndServicesType", ProductAndServicesTypeRestriction) Then
		Parameters.AdditionalParameters.Property("TypeRestriction", ProductAndServicesTypeRestriction);
	EndIf;
		
	If Not ProductAndServicesTypeRestriction = Undefined Then
		If (TypeOf(ProductAndServicesTypeRestriction) = Type("Array") Or TypeOf(ProductAndServicesTypeRestriction) = Type("FixedArray")) 
			AND ProductAndServicesTypeRestriction.Count() > 0 Then
			
			List.Clear();
			For Each Type IN ProductAndServicesTypeRestriction Do
				List.Add(Type);
			EndDo;
			
		ElsIf TypeOf(ProductAndServicesTypeRestriction) = Type("EnumRef.ProductsAndServicesTypes") Then
			
			List.Clear();
			List.Add(ProductAndServicesTypeRestriction);
			
		EndIf;
		
	EndIf;
	
	If Not Constants.FunctionalOptionUseTechOperations.Get() Then
		FoundOperation = Items.ProductsAndServicesType.ChoiceList.FindByValue(Enums.ProductsAndServicesTypes.Operation);
		If FoundOperation <> Undefined Then
			Items.ProductsAndServicesType.ChoiceList.Delete(FoundOperation);
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.ProductsAndServicesType) 
		Or Items.ProductsAndServicesType.ChoiceList.FindByValue(Object.ProductsAndServicesType) = Undefined Then
			Object.ProductsAndServicesType = List.Get(0).Value;
	EndIf;
	
	If List.Count() = 1 Then
		Items.ProductsAndServicesType.Enabled = False;
	EndIf;
	
EndProcedure // FillTypesList()
 

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	If Object.FixedCost = True Then
		RadioButtonCalculationMethodValue = "Fixed cost";
	Else
		RadioButtonCalculationMethodValue = "Time norm";
	EndIf;
	MetadataObject = Object.Ref.Metadata();
	Items.RadioButtonCalculationMethodValue.ReadOnly = Not (AccessRight("Insert", MetadataObject)
		OR AccessRight("Update", MetadataObject));
	
	SetVisibleAndEnabled();
	
	GenerateDescriptionFullAutomatically = SetFlagToFormDescriptionFullAutomatically(
		Object.Description,
		Object.DescriptionFull
	);
	
	If Not ValueIsFilled(Object.Ref) Then
		
		FillListTypes();
		
		If Not ValueIsFilled(Parameters.CopyingValue) Then
			Object.VATRate = Catalogs.Companies.MainCompany.DefaultVATRate;
		EndIf;
		
		If Not ValueIsFilled(Object.ExpensesGLAccount) Then
			
			Object.ExpensesGLAccount = ?(
				Object.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service
					OR Not Constants.FunctionalOptionUseSubsystemProduction.Get(),
				ChartsOfAccounts.Managerial.CommercialExpenses,
				ChartsOfAccounts.Managerial.UnfinishedProduction
			);
			
		EndIf;
		
		If Not IsBlankString(Parameters.FillingText) AND GenerateDescriptionFullAutomatically Then
			Object.DescriptionFull = Parameters.FillingText;
		EndIf;
		
		FillAlcoholProductsAttributesByItemGroup();
		
	EndIf;
	
	InsertImagesFromProductsAndServices = False;
	
	// Work with prices
	PriceKind = Catalogs.PriceKinds.GetMainKindOfSalePrices();
	FillBasicSalesPriceOnServer();
	
	NotifyPickup = False;
	ItemModified = False;
	
	PictureURL = ?(Object.PictureFile.IsEmpty(), "", URLImages(Object.PictureFile, UUID));
	Items.PictureURL.ReadOnly = Not AccessRight("Edit", Object.Ref.Metadata());
	
	// FO Use the subsystems Production, Work.
	SetVisibleByFOUseProductionJobsSubsystem();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesPage");
	// End StandardSubsystems.Properties
	
EndProcedure // OnCreateAtServer()

&AtServer
// Event handler procedure OnReadAtServer
//
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // OnReadAtServer()

// SelectionProcessor form event handler procedure
//
&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.AttachedFiles"
		AND ValueIsFilled(ValueSelected) Then
		
		Object.PictureFile = ValueSelected;
		PictureURL = URLImages(Object.PictureFile, UUID)
		
	EndIf;
	
EndProcedure // ChoiceProcessing()

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Mechanism handler "Properties".
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
	If EventName = "PriceChanged"
		AND Parameter Then
		
		InitiateFillingBasicSalesPriceOnClient();
		
	ElsIf InsertImagesFromProductsAndServices
		AND EventName = "Record_AttachedFile" Then
		
		Modified	= True;
		Object.PictureFile	= ?(TypeOf(Source) = Type("Array"), Source[0], Source);
		PictureURL		= URLImages(Object.PictureFile, UUID);
		InsertImagesFromProductsAndServices = False;
		
	EndIf;
	
	If EventName = "ProductsAndServicesAccountsChanged" Then
		
		Object.InventoryGLAccount = Parameter.InventoryGLAccount;
		Object.ExpensesGLAccount = Parameter.ExpensesGLAccount;
		Modified = True;
		
	EndIf;
	
EndProcedure // NotificationProcessing()

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure // FillCheckProcessingAtServer()

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Mechanism handler "Properties".
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
			
	If Modified Then
		ItemModified = True;	
	EndIf;
	
EndProcedure // BeforeWriteAtServer()

&AtServer
// Procedure-handler  of the AfterWriteOnServer event.
//
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
	If ItemModified Then
		NotifyPickup = True;
		ItemModified = False;
	EndIf;
	
	SetChangeBasicSalesPrice();
	
EndProcedure // AfterWriteOnServer()

&AtClient
// BeforeRecord event handler procedure.
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("CatalogProductsAndServicesWrite");
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure //BeforeWrite()

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If NotifyPickup 
		AND TypeOf(ThisForm.FormOwner) = Type("ManagedForm")
		AND ThisForm.FormOwner.FormName = "CommonForm.PickForm" Then
		Notify("RefreshPickup", True);
	// CWP
	ElsIf NotifyPickup 
		AND TypeOf(ThisForm.FormOwner) = Type("ManagedForm")
		AND Find(ThisForm.FormOwner.FormName, "DocumentForm_CWP") > 0 Then
		Notify("ProductsAndServicesIsAddedFromCWP", Object.Ref);
	EndIf;
	// End CWP
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - OnChange event handler of the Description field.
//
Procedure DescriptionOnChange(Item)

	If GenerateDescriptionFullAutomatically Then
		
		Object.DescriptionFull = Object.Description;
		
	EndIf;
	
EndProcedure // DescriptionOnChange()

&AtClient
// Procedure - OnChange event handler of the ProductsAndServicesType field.
//
Procedure ProductsAndServicesTypeOnChange(Item)
	
	Object.InventoryGLAccount = Undefined;
	Object.ExpensesGLAccount = Undefined;
	SetVisibleAndEnabled(True);
	
EndProcedure // ProductsAndServicesTypeOnChange()

&AtClient
// Procedure - Open event handler of the Warehouse field.
//
Procedure WarehouseOpening(Item, StandardProcessing)
	
	If Items.Warehouse.ListChoiceMode
		AND Not ValueIsFilled(Object.Warehouse) Then
		
		StandardProcessing = False;
		
	EndIf;	
	
EndProcedure // WarehouseOpening()

&AtClient
// Procedure - SelectionStart event handler of the Specification field.
//
Procedure SpecificationStartChoice(Item,  ChoiceData, StandardProcessing)
		
	If Not ValueIsFilled(Object.Ref) Then
		
		StandardProcessing = False;
		Message = New UserMessage();
		Message.Text = NStr("en='Catalog item is not recorded yet';ru='Элемент справочника еще не записан.'");
		Message.Message();
		
	EndIf;

EndProcedure // SpecificationSelectionStart()

&AtClient
// Procedure - OnChange event handler of the ImageFile field.
//
Procedure PictureFileOnChange(Item)
	
	PictureURL = ?(Object.PictureFile.IsEmpty(), "", URLImages(Object.PictureFile, UUID));
	
EndProcedure

&AtClient
Procedure PictureFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoosePictureFromAttachedFiles();
	
EndProcedure

&AtClient
// Procedure - Click event handler of the ImageURL address.
//
Procedure PictureURLClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	If Items.PictureURL.ReadOnly Then
		Return;
	EndIf;
	
	LockFormDataForEdit();
	AddImageAtClient();
	
EndProcedure // ImageAddressClick()

// Procedure - OnChange fields ProductsAndServicesCategory events handler.
//
&AtClient
Procedure ProductsAndServicesCategoryOnChange(Item)
	
	FillAlcoholProductsAttributesByItemGroup();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the PricingMethodOnChange check box.
//
Procedure RadioButtonCalculationMethodValueOnChange(Item)
	
	If RadioButtonCalculationMethodValue = "Fixed cost" Then
		Object.FixedCost = True;
	Else
	    Object.FixedCost = False;	
	EndIf; 
	
EndProcedure

&AtClient
Procedure CountryOfOriginOnChange(Item)
	
	If Object.CountryOfOrigin = PredefinedValue("Catalog.WorldCountries.Russia")
		OR Not ValueIsFilled(Object.CountryOfOrigin) Then
		Object.ImportedAlcoholicProducts = False;
	Else
		Object.ImportedAlcoholicProducts = True;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the DescriptionFull attribute
//
&AtClient
Procedure DescriptionFullOnChange(Item)
	
	GenerateDescriptionFullAutomatically = SetFlagToFormDescriptionFullAutomatically(Object.Description, Object.DescriptionFull);
	
EndProcedure // DescriptionFullOnChange()

// Procedure - Click event handler of the History attribute
//
&AtClient
Procedure PriceChangeHistoryClick(Item)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		WarningText = NStr("en='Item is not recorded. You can not open the price history of the item that is not recorded.';ru='Элемент не записан. Открыть историю цен незаписанного элемента не возможно.'");
		HeaderText 		= NStr("en='You can not open the price history';ru='Невозможно открыть историю цен'");
		
		ShowMessageBox(Undefined,WarningText, 20, HeaderText);
		Return;
		
	EndIf;
	
	StructureFilter = New Structure;
	StructureFilter.Insert("ProductsAndServices", Object.Ref);
	StructureFilter.Insert("PriceKind", PriceKind);
	
	OpenForm("InformationRegister.ProductsAndServicesPrices.ListForm", New Structure("Filter", StructureFilter));
	
EndProcedure // HistoryClick()

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// Procedure - AddImage command handler
//
&AtClient
Procedure AddImage(Command)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		QuestionText = NStr("en='To select the image it is necessary to record the object. Record?';ru='Для выбора изображения необходимо записать объект. Записать?'");
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("AddImageEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo);
		
	Else
		
		AddImageFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddImageEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return
    EndIf;
    
    Write();
    
    
    AddImageFragment();

EndProcedure

&AtClient
Procedure AddImageFragment()
	Var FileID;
	
	InsertImagesFromProductsAndServices = True;
	FileID = New UUID;
	AttachedFilesClient.AddFiles(Object.Ref, FileID);
	
EndProcedure // AddImage()

// Procedure - ChangeImage command handler
//
&AtClient
Procedure ChangeImage(Command)
	
	ClearMessages();
	
	If ValueIsFilled(Object.PictureFile) Then
		
		AttachedFilesClient.OpenAttachedFileForm(Object.PictureFile);
		
	Else
		
		MessageText = NStr("en='Picture for editing is absent';ru='Отсутстует изображение для редактирования'");
		CommonUseClientServer.MessageToUser(MessageText,, "PictureURL");
		
	EndIf;
	
EndProcedure // ChangeImage()

// Procedure - ClearImage command handler
//
&AtClient
Procedure ClearImage(Command)
	
	Object.PictureFile = Undefined;
	PictureURL = "";
	
EndProcedure // ClearImage()

// Procedure - ClearImage command handler
//
&AtClient
Procedure SeeImage(Command)
	
	SeeAttachedFile();
	
EndProcedure // ViewImage()

// Procedure - SelectImageFromAttachedFiles command handler
&AtClient
Procedure PictureFromAttachedFiles(Command)
	
	ChoosePictureFromAttachedFiles();
	
EndProcedure // SelectImageFromAttachedFiles()


#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisObject, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.ObjectsAttributesEditProhibition
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ObjectsAttributesEditProhibitionClient.AllowObjectAttributesEditing(ThisObject);
	
EndProcedure // Attachable_AllowObjectAttributesEditing()
// End

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

#EndRegion
