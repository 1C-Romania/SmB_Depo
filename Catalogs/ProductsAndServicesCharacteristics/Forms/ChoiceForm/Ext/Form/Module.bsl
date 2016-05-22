
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Sets filter for products and services characteristic choice form.
//
Procedure SetFilterByOwnerAtServer()
	
	FilterList = New ValueList;
	FilterList.Add(ProductsAndServices);
	FilterList.Add(ProductsAndServicesCategory);
	
	SmallBusinessClientServer.SetListFilterItem(List,"Owner",FilterList,True,DataCompositionComparisonType.InList);
	
EndProcedure // SetFilterByOwnerAtServer()

&AtClient
// Sets filter for products and services characteristic choice form.
//
Procedure SetFilterByOwnerAtClient()
	
	FilterList = New ValueList();
	FilterList.Add(ProductsAndServices);
	FilterList.Add(ProductsAndServicesCategory);
	
	SmallBusinessClientServer.SetListFilterItem(List,"Owner",FilterList,True,DataCompositionComparisonType.InList);
	
EndProcedure // SetFilterByOwnerAtClient()

&AtServer
// Fill property tree by values.
//
Procedure FillValuesPropertiesTree(WrapValuesEntered, AdditionalAttributes)
	
	If WrapValuesEntered Then
		PropertiesManagementOverridable.MovePropertiesValues(AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	EndIf;
	
	PrListOfSets = New ValueList;
	Set = ProductsAndServicesCategory.SetOfCharacteristicProperties;
	If Set <> Undefined Then
		PrListOfSets.Add(Set);
	EndIf;
	
	Tree = PropertiesManagementOverridable.FillValuesPropertiesTree(ProductsAndServicesCategory, AdditionalAttributes, True, PrListOfSets);
	ValueToFormAttribute(Tree, "PropertiesValuesTree");
	//ValueToFormAttribute(Tree, "Attribute1");
	
EndProcedure // FillValuesPropertiesTree()

&AtClient
// Procedure traverses the value tree recursively.
//
Procedure SetFilterByPropertiesAndValues(TreeItems)
	
	For Each TreeRow IN TreeItems Do
		
		If ValueIsFilled(TreeRow.Value) Then
			
			SmallBusinessClientServer.SetListFilterItem(List,"Ref.[" + String(TreeRow.Property)+"]",TreeRow.Value);
			
		EndIf;
		
		NextTreeItem = TreeRow.GetItems();
		SetFilterByPropertiesAndValues(NextTreeItem);
		
	EndDo;
	
EndProcedure // RecursiveBypassOfValueTree()

&AtServer
// Procedure traverses the value tree recursively.
//
Procedure RecursiveBypassOfValueTree(TreeItems, String)
	
	For Each TreeRow IN TreeItems Do
		
		If ValueIsFilled(TreeRow.Value) Then
			If IsBlankString(TreeRow.FormatProperties) Then
				String = String + TreeRow.Value + ", ";
			Else
				String = String + Format(TreeRow.Value, TreeRow.FormatProperties) + ", ";
			EndIf;
		EndIf;
		
		NextTreeItem = TreeRow.GetItems();
		RecursiveBypassOfValueTree(NextTreeItem, String);
		
	EndDo;
	
EndProcedure // RecursiveBypassOfValueTree()

&AtServer
// Function sets new characteristic description by the property values.
//
// Parameters:
//  PropertiesValuesCollection - a value collection with property Value.
//
// Returns:
//  String - generated description.
//
Function GenerateDescription(PropertiesValuesCollection)

	TreeItems = PropertiesValuesCollection.GetItems();
	
	String = "";
	RecursiveBypassOfValueTree(TreeItems, String);
	
	String = Left(String, StrLen(String) - 2);

	If IsBlankString(String) Then
		String = "<Properties aren't assigned>";
	EndIf;

	Return String;

EndFunction // GenerateDescription()

&AtServer
// Enters a new characteristic in compliance with the established property values.
//
// Parameters:
//  No.
//
Procedure EnterNewCharacteristic()
	
	CatalogObjectCharacteristic = Catalogs.ProductsAndServicesCharacteristics.CreateItem();
	
	CatalogObjectCharacteristic.Owner = ProductsAndServices;
	CatalogObjectCharacteristic.Description = GenerateDescription(PropertiesValuesTree);
	
	// Transfer the values from property value tree in tabular object section.
	PropertiesManagementOverridable.MovePropertiesValues(CatalogObjectCharacteristic.AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	
	BeginTransaction();
	
	Try
		CatalogObjectCharacteristic.Write();
		
	Except
		SmallBusinessServer.ShowMessageAboutError(,ErrorDescription());
		Return;
	EndTry;
	
	CommitTransaction();
	
	// Update dynamic list data.
	Items.List.CurrentRow = CatalogObjectCharacteristic.Ref;
	Items.List.Refresh();
	
EndProcedure // EnterNewCharacteristic()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - setting the filter for choice form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") AND TypeOf(Parameters.Filter.Owner) = Type("CatalogRef.ProductsAndServices") Then
		
		ProductsAndServices = Parameters.Filter.Owner;
		ProductsAndServicesCategory = Parameters.Filter.Owner.ProductsAndServicesCategory;
		
		MessageText = "";
		If Not ValueIsFilled(ProductsAndServices) Then
			MessageText = NStr("en = 'Products and services are not filled!'");
		ElsIf Parameters.Property("ThisIsReceiptDocument") AND ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service Then
			MessageText = NStr("en = 'The third party services are not accounted by characteristics!'");
		ElsIf Not ProductsAndServices.UseCharacteristics Then
			MessageText = NStr("en = 'The products and services are not accounted by characteristics!'");
		EndIf;
		
		If Not IsBlankString(MessageText) Then
			CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
			Return;
		EndIf;
		
		// Clean the passed filter and set its
		Parameters.Filter.Delete("Owner");
		SetFilterByOwnerAtServer();
		
		// Fill the property value tree.
		FillValuesPropertiesTree(False, Parameters.CurrentRow.AdditionalAttributes);
		
	Else
		
		Items.ListCreate.Enabled = False;
		Items.ListContextMenuCreate.Enabled = False;
		
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalAttributesAndInformation") Then
		Items.Characteristics.Representation = UsualGroupRepresentation.None;
		Items.Characteristics.ShowTitle = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
// Event handler procedure OnOpen.
//
Procedure OnOpen(Cancel)
	
	// Develop the property value tree.
	SmallBusinessClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	
EndProcedure // OnOpen()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS PROPERTIES AND VALUES

&AtClient
// Procedure - event handler OnChange input field Value.
//
Procedure ValueOnChange(Item)
	
	List.SettingsComposer.Settings.Filter.Items.Clear();
	
	SetFilterByOwnerAtClient();
	
	TreeItems = PropertiesValuesTree.GetItems();
	SetFilterByPropertiesAndValues(TreeItems);
	
EndProcedure // ValueOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTION ATTRIBUTE EVENT HANDLERS CHARACTERISTICS

&AtClient
// Procedure - event handler BeforeAddStart input field List.
//
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	EnterNewCharacteristic();
	
EndProcedure // ListBeforeAddStart()

////////////////////////////////////////////////////////////////////////////////
// PROPERTY MECHANISM PROCEDURES

&AtClient
// Procedure - event handler OnChange input field PropertyValueTree.
//
Procedure PropertyValueTreeOnChange(Item)
	
	ThisForm.Modified = True;
	
EndProcedure // PropertyValueTreeOnChange()

&AtClient
// Procedure - event handler BeforeAddStart input field PropertyValueTree.
//
Procedure PropertyValueTreeBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure // PropertyValueTreeBeforeAddStart()

&AtClient
// Procedure - event handler BeforeDelete input field PropertyValueTree.
//
Procedure PropertyValueTreeBeforeDelete(Item, Cancel)
	
	SmallBusinessClient.PropertyValueTreeBeforeDelete(Item, Cancel, Modified);
	
EndProcedure // PropertyValuesTreeBeforeDeletion()

&AtClient
// Procedure - event handler WhenEditStart input field PropertyValueTree.
//
Procedure PropertyValueTreeOnStartEdit(Item, NewRow, Copy)
	
	SmallBusinessClient.PropertyValueTreeOnStartEdit(Item);
	
EndProcedure // PropertyValueTreeOnStartEdit()
