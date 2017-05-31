#Region BaseFormProcedures
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	TypeDescription = ?(Parameters.Property("TypeDescription"), GetFromTempStorage(Parameters.TypeDescription), Undefined);	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ArrayToExpand = GetAvailableTypesTree(TypeDescription);
	
	For Each RowID In ArrayToExpand Do
	    If RowID<>Undefined Then
			Items.AvailableTypes.Expand(RowID);
		EndIf;			
	EndDo;
	
	If ArrayOfMarkedItems.Count() > 1 Then
		CompoundDataType = True;
	EndIf;	
	
	If ArrayOfMarkedItems.Count() > 0 Then
			
		Items.AvailableTypes.CurrentRow = ArrayOfMarkedItems[0].Value;
	EndIf;

EndProcedure

#EndRegion

#Region StandardCommonCommands

&AtClient
Procedure CommandOK(Command)
	TypesArray = New Array();
	
	CommandOkAtServer(TypesArray);
	
	If TypesArray.Count() = 0 Then
		ShowMessageBox( , Nstr("en = 'At least one type should be selected!'; pl = 'Przynajmniej jeden typ powinien byc wybrany!'"), , Nstr("en='Choose type';pl='Wybierz typ'"));
	Else
		TypeDescription = New TypeDescription(TypesArray);
		Close(TypeDescription);			
	EndIf;
EndProcedure

&AtServer
Procedure CommandOKAtServer(TypesArray)
	For Each ArrayOfMarkedItemsItem In ArrayOfMarkedItems Do
		CurrentAvailableTypes = AvailableTypes.FindByID(ArrayOfMarkedItemsItem.Value);
		
		For Each Type In CurrentAvailableTypes.Value.Types() Do
			
			TypesArray.Add(Type);
			
		EndDo;	
		
	EndDo;
EndProcedure

#EndRegion

#Region ItemsEvents

&AtClient
Procedure CompoundDataTypeOnChange(Item)
	
	If NOT CompoundDataType Then
		ClearMarks(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure AvailableTypesOnEditEnd(Item, NewRow, CancelEdit)
	
	CurrentData = Item.CurrentData;	
	If CurrentData.Mark Then
		
		If NOT CompoundDataType AND ArrayOfMarkedItems.Count() > 0 Then
			
			ClearMarks();
			
		EndIf;
		
		ArrayOfMarkedItems.Add(Item.CurrentData.GetId());
		
	Else
		ArrayOfMarkedItems.Delete(ArrayOfMarkedItems.FindByValue(Item.CurrentData.GetId()));
	EndIf;
	
EndProcedure

#EndRegion

#Region Other

&AtServer
Function AddTreeRow(Parent, Presentation, Val Value, Picture = Undefined, TypeDescriptionToSetMarks)
	
	Mark = False;
	
	If TypeOf(Value) <> Type("TypeDescription") Then
		Array = New Array;
		Array.Add(Value);
		TypeDescriptionValue = New TypeDescription(Array);
	
		If TypeDescriptionToSetMarks <> Undefined 
			AND TypeDescriptionToSetMarks.ContainsType(Value)
			AND ((TypeOf(Parent) = Type("FormDataTreeItem") AND NOT Parent.Mark)
			OR TypeOf(Parent) = Type("FormDataTree")) Then
			Mark = True;
		EndIf;	
	Else
		TypeDescriptionValue = Value;
		If TypeDescriptionToSetMarks <> Undefined Then
			NotAllRefs = False;
			For Each Type In Value.Types() Do
				
				If NOT TypeDescriptionToSetMarks.ContainsType(Type) Then
					
					NotAllRefs = True;
					Break;
					
				EndIf;	
				
			EndDo;	
			
			If NOT NotAllRefs Then
				Mark = True;
			EndIf;	
		EndIf;
		
	EndIf;	
	
	NewRow = Parent.GetItems().Add();
	NewRow.Presentation = Presentation;
	NewRow.Value = TypeDescriptionValue;
	NewRow.Mark = Mark;
	NewRow.TablePicture = Picture;
	
	If Mark Then
		ArrayOfMarkedItems.Add(NewRow.GetId());
	EndIf;	
	
	Return NewRow;
	
EndFunction

&AtServer
Function AddFolderWithContentToTypesTree(TypeDescriptionToSetMarks, MetadataGroup, DataGroup, FolderPresentation, Picture)
	NeedToExpand = Undefined;
	LocalAvailableTypesChoiceList = New ValueList;
	For Each MetadataGroupItem In MetadataGroup Do
		LocalAvailableTypesChoiceList.Add(TypeOf(DataGroup[MetadataGroupItem.Name].EmptyRef()), MetadataGroupItem.Synonym, , Picture);
	EndDo;	
	LocalAvailableTypesChoiceList.SortByPresentation();
	
	ParentFolder = AddTreeRow(AvailableTypes, FolderPresentation, DataGroup.AllRefsType(), Picture, TypeDescriptionToSetMarks);
	
	NeedToExpand = False;
	For Each SortedItem In LocalAvailableTypesChoiceList Do
		NewRow = AddTreeRow(ParentFolder, SortedItem.Presentation, SortedItem.Value, SortedItem.Picture, TypeDescriptionToSetMarks);
		If NewRow.Mark Then
			NeedToExpand = ParentFolder.GetID();			
		EndIf;	
	EndDo;
	Return NeedToExpand;
EndFunction

&AtServer
Function GetAvailableTypesTree(TypeDescriptionToSetMarks) Export
	
	AvailableTypes.GetItems().Clear();

	AddTreeRow(AvailableTypes,String(Type("Number")),Type("Number"),,TypeDescriptionToSetMarks);
	AddTreeRow(AvailableTypes,String(Type("String")),Type("String"),,TypeDescriptionToSetMarks);
	AddTreeRow(AvailableTypes,String(Type("Date")),Type("Date"),,TypeDescriptionToSetMarks);
	AddTreeRow(AvailableTypes,String(Type("Boolean")),Type("Boolean"),,TypeDescriptionToSetMarks);
	AddTreeRow(AvailableTypes,Nstr("en='Account type';pl='Typ konta'"),Type("AccountType"),,TypeDescriptionToSetMarks);
	AddTreeRow(AvailableTypes,Nstr("en='Accounting record type';pl='Typ księgowego zapisu'"),Type("AccountingRecordType"),,TypeDescriptionToSetMarks);
	AddTreeRow(AvailableTypes,Nstr("en='Record type';pl='Typ zapisu'"),Type("AccumulationRecordType"),,TypeDescriptionToSetMarks);
	
	ArrayToExpand = New Array;
	ArrayToExpand.Add(AddFolderWithContentToTypesTree(TypeDescriptionToSetMarks,Metadata.Catalogs,Catalogs,Nstr("en = 'Catalog''s references'; pl = 'Odnośniki do katalogów'"),PictureLib.Catalog));
	ArrayToExpand.Add(AddFolderWithContentToTypesTree(TypeDescriptionToSetMarks,Metadata.Documents,Documents,Nstr("en = 'Document''s references'; pl = 'Odnośniki do dokumentów'"),PictureLib.Document));
	ArrayToExpand.Add(AddFolderWithContentToTypesTree(TypeDescriptionToSetMarks,Metadata.Enums,Enums,Nstr("en = 'Enum''s references'; pl = 'Odnośniki do enumeracji'"),PictureLib.Enum));
	ArrayToExpand.Add(AddFolderWithContentToTypesTree(TypeDescriptionToSetMarks,Metadata.ChartsOfCharacteristicTypes,ChartsOfCharacteristicTypes,Nstr("en = 'Charts of characteristic types references'; pl = 'Odnośniki do planów rodzajów charakterystyk'"),PictureLib.ChartOfCharacteristicTypes));
	ArrayToExpand.Add(AddFolderWithContentToTypesTree(TypeDescriptionToSetMarks,Metadata.ChartsOfAccounts,ChartsOfAccounts,Nstr("en = 'Charts of accounts references'; pl = 'Odnośniki do planów kont'"),PictureLib.ChartOfAccounts));
		
	Return ArrayToExpand;
EndFunction

&AtServer
Procedure ClearMarks(ClearWithoutLast = False)

	SavedValue = Undefined;		
	If ClearWithoutLast Then 
		SavedValue = ArrayOfMarkedItems.Get(ArrayOfMarkedItems.Count() - 1).Value;
	EndIf;
	
	For i = 0 To ArrayOfMarkedItems.Count() - 1 - ?(ClearWithoutLast,1,0) Do
		AvailableTypes.FindByID(ArrayOfMarkedItems.Get(i).Value).Mark=False;
	EndDo;
	
	ArrayOfMarkedItems.Clear();
	
	If SavedValue<>Undefined Then
		ArrayOfMarkedItems.Add(SavedValue);
	EndIf;		

EndProcedure

#EndRegion






