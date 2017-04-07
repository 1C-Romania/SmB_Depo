
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FilterKind = Parameters.FilterKind;
	ListValueSelection 	   = Parameters.ListValueSelection;
	
	TypeArray = New Array();
	If FilterKind = "FilterByProductsAndServices" Then
		Title = NStr("en='Select products and services';ru='Выберите номенклатуру'");
		Items.ProductsAndServicesGroupValue.ChoiceFoldersAndItems = FoldersAndItems.Items;
		TypeArray.Add(Type("CatalogRef.ProductsAndServices"));
	ElsIf FilterKind = "FilterByProductsAndServicesGroups" Then
		Title = NStr("en='Choose ProductsAndServices groups';ru='Выберите группы номенклатуры'");
		Items.ProductsAndServicesGroupValue.ChoiceFoldersAndItems = FoldersAndItems.Folders;
		TypeArray.Add(Type("CatalogRef.ProductsAndServices"));
	Else
		Title = NStr("en='Select products and services categories';ru='Выберите номенклатурные группы'");
		Items.ProductsAndServicesGroupValue.ChoiceFoldersAndItems = FoldersAndItems.Items;
		TypeArray.Add(Type("CatalogRef.ProductsAndServicesCategories"));
	EndIf;
	
	NewDetails = New TypeDescription(TypeArray);
	ListValueSelection.ValueType = NewDetails;
	
EndProcedure

// Fills item presentations and delete empty values.
//
&AtServerNoContext
Procedure FillPresentationOfListItemsServerNoContext(ListValueSelection)
	
	ArrayOfItemsForDeletion = New Array;
	
	For Each ItemOfList IN ListValueSelection Do
	
		If Not ValueIsFilled(ItemOfList.Value) Then
			
			ArrayOfItemsForDeletion.Add(ItemOfList);
			Continue;
			
		EndIf;
		
		ItemOfList.Presentation = ItemOfList.Value.Description;
	
	EndDo;
	
	For Each ArrayElement IN ArrayOfItemsForDeletion Do
	
		ListValueSelection.Delete(ArrayElement);
	
	EndDo;
	
EndProcedure

&AtClient
Procedure CommandOK(Command)
	
	FillPresentationOfListItemsServerNoContext(ListValueSelection);
	
	SelectionResult = New Structure;
	SelectionResult.Insert("FilterKind", FilterKind);
	SelectionResult.Insert("SelectionValueListAddress", PutToTempStorage(ListValueSelection));
	
	Close(SelectionResult);
	
EndProcedure







