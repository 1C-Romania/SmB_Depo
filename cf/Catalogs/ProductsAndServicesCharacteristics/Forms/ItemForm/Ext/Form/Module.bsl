
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Fill property tree by values.
//
Procedure FillValuesPropertiesTree(WrapValuesEntered)
	
	If WrapValuesEntered Then
		PropertiesManagementOverridable.MovePropertiesValues(Object.AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	EndIf;
	
	PrListOfSets = New ValueList;
	Set = ProductsAndServicesCategory.SetOfCharacteristicProperties;
	If Set <> Undefined Then
		PrListOfSets.Add(Set);
	EndIf;
	
	Tree = PropertiesManagementOverridable.FillValuesPropertiesTree(Object.Ref, Object.AdditionalAttributes, True, PrListOfSets);
	ValueToFormAttribute(Tree, "PropertiesValuesTree");
	
EndProcedure // FillValuesPropertiesTree()

&AtServerNoContext
// Function returns products and services owner category.
//
Function GetOwnerProductsAndServicesCategory(ProductsAndServicesOwner)
	
	Return ProductsAndServicesOwner.ProductsAndServicesCategory;
	
EndFunction // GetOwnerProductsAndServicesCategory()

&AtClient
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

&AtClient
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
// Procedure - fills choice list for attribute Owner.
//
Procedure FillChoiceListOwner()
	
	Items.Owner.ChoiceList.Clear();
	If ValueIsFilled(ProductsAndServicesCategory) Then
		Items.Owner.ChoiceList.Add(ProductsAndServicesCategory);
	EndIf;
	If ValueIsFilled(ProductsAndServices) Then
		Items.Owner.ChoiceList.Add(ProductsAndServices);
	EndIf;
	
EndProcedure // FillOwnerChoiceList()

&AtClient
// Procedure - fills choice list for attribute Description.
//
Procedure FillChoiceListItems()
	
	Items.Description.ChoiceList.Clear();
	Items.Description.ChoiceList.Add(GenerateDescription(PropertiesValuesTree));
	
EndProcedure // FillDescriptionChoiceList()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// 1. Checking.
	If ValueIsFilled(Object.Owner)
		AND TypeOf(Object.Owner) = Type("CatalogRef.ProductsAndServices")
		AND Not Object.Owner.UseCharacteristics Then
		
		Message = New UserMessage();
		Message.Text = NStr("en='The products and services are not accounted by characteristics!
		|Select the ""Use characteristics"" check box in products and services card';ru='Для номенклатуры не ведется учет по характеристикам!
		|Установите флаг ""Использовать характеристики"" в карточке номенклатуры'");
		Message.Message();
		Cancel = True;
		
	// 2. Filling.
	ElsIf Parameters.Property("FillingValues") AND Parameters.FillingValues.Property("Owner") Then
		
		If TypeOf(Parameters.FillingValues.Owner) = Type("CatalogRef.ProductsAndServices") Then
		
			ProductsAndServicesCategory = Parameters.FillingValues.Owner.ProductsAndServicesCategory;
			ProductsAndServices = Parameters.FillingValues.Owner;
			
		ElsIf TypeOf(Parameters.FillingValues.Owner) = Type("CatalogRef.ProductsAndServicesCategories") Then
			
			ProductsAndServicesCategory = Parameters.FillingValues.Owner;
			ProductsAndServices = Undefined;
			
		ElsIf TypeOf(Parameters.FillingValues.Owner) = Type("ValueList") Then
			
			For Each ListIt IN Parameters.FillingValues.Owner Do
				
				If TypeOf(ListIt.Value) = Type("CatalogRef.ProductsAndServicesCategories") Then
					
					Object.Owner = ListIt.Value;
					ProductsAndServicesCategory = ListIt.Value;
					
				Else
					
					ProductsAndServices = ListIt.Value;
					
				EndIf;
				
			EndDo;
		
		EndIf;
		
	// 3 Open.
	ElsIf ValueIsFilled(Parameters.Key) Then
		
		If TypeOf(Parameters.Key.Owner) = Type("CatalogRef.ProductsAndServices") Then
		
			ProductsAndServicesCategory = Parameters.Key.Owner.ProductsAndServicesCategory;
			ProductsAndServices = Parameters.Key.Owner;
			
		ElsIf TypeOf(Parameters.Key.Owner) = Type("CatalogRef.ProductsAndServicesCategories") Then
			
			ProductsAndServicesCategory = Parameters.Key.Owner;
			ProductsAndServices = Undefined;

		EndIf;
		
	Else
		
		ProductsAndServicesCategory = Undefined;
		ProductsAndServices = Undefined;
		
	EndIf;
	
	// Fill the property value tree.
	If Not Cancel Then
		FillChoiceListOwner();
		FillValuesPropertiesTree(False);
	EndIf;
	
	If Not GetFunctionalOption("UseAdditionalAttributesAndInformation") Then
		Items.Description.DropListButton = False;
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtClient
// Event handler procedure OnOpen.
//
Procedure OnOpen(Cancel)
	
	// Deploy property value tree.
	SmallBusinessClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	FillChoiceListItems();
	
EndProcedure // OnOpen()

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Transfer the values from property value tree in tabular object section.
	PropertiesManagementOverridable.MovePropertiesValues(CurrentObject.AdditionalAttributes, FormAttributeToValue("PropertiesValuesTree"));
	
EndProcedure // BeforeWriteAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

&AtClient
// Procedure - event handler OnChange field Owner.
//
Procedure OwnerOnChange(Item)
	
	If TypeOf(Object.Owner) = Type("CatalogRef.ProductsAndServices") Then
		
		ProductsAndServicesCategory = GetOwnerProductsAndServicesCategory(Object.Owner);
		
	ElsIf TypeOf(Object.Owner) = Type("CatalogRef.ProductsAndServicesCategories") Then
		
		ProductsAndServicesCategory = Object.Owner;
		
	Else
		
		ProductsAndServicesCategory = Undefined;
		
	EndIf;
	
	// Fill the property value tree.
	FillValuesPropertiesTree(True);
	
	SmallBusinessClient.ExpandPropertiesValuesTree(Items.PropertiesValuesTree, PropertiesValuesTree);
	
EndProcedure // OwnerOnChange()

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
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure PropertyValueTreeOnChange(Item)
	
	Object.Description = GenerateDescription(PropertiesValuesTree);
	
	ThisForm.Modified = True;
	
EndProcedure // PropertyValueTreeOnChange()

&AtClient
Procedure PropertyValueTreeBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure // PropertyValueTreeBeforeAddStart()

&AtClient
Procedure PropertyValueTreeBeforeDelete(Item, Cancel)
	
	SmallBusinessClient.PropertyValueTreeBeforeDelete(Item, Cancel, Modified);
	
EndProcedure // PropertyValuesTreeBeforeDeletion()

&AtClient
Procedure PropertyValueTreeOnStartEdit(Item, NewRow, Copy)
	
	SmallBusinessClient.PropertyValueTreeOnStartEdit(Item);
	
EndProcedure // PropertyValueTreeOnStartEdit()
// End StandardSubsystems.Properties

#EndRegion

