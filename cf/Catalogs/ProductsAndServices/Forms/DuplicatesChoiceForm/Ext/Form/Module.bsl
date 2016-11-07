
//start Bernavski

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)       
	
	InscriptionMessage = NStr("ru = 'В справочнике ""Номенклатура"" найдены дублирующие элементы.
	|Отменить запись текущей номенклатуры, заменив её номенклатурой из списка?'; en = 'The catalog "" ProductsAndServices "" found duplicate elements.
	|To cancel recording the current element, replacing it with the product or service from the list?'"); 
	
	ArrayOfRef = New Array;
	For each ItemFound In Parameters.FoundObjects Do
		ArrayOfRef.Add(ItemFound.Value.Ref);	
	EndDo;
	
	ListOfNomenclature.Parameters.SetParameterValue("ArrayOfRef", ArrayOfRef);
	    
	For each ItemFound In Parameters.FoundObjects Do
		SetListAppearance(ItemFound.Value, ListOfNomenclature.ConditionalAppearance);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetListAppearance(ItemFound, Val ConditionalAppearance)

	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = ItemFound.Ref;
	DataFilterItem.Use = True;
	
	ColorAppearanceItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	ColorAppearanceItem.Value =  Metadata.StyleItems.ExplanationTextError.Value; 
	ColorAppearanceItem.Use = True;
	
	If ItemFound.Свойство("Description_Flag") And ItemFound.Description_Flag Then
		NewElement = ConditionalAppearanceItem.Fields.Items.Add();
		NewElement.Field = New DataCompositionField("Description");		
	EndIf;
	
	If ItemFound.Свойство("SKU_Flag") And ItemFound.SKU_Flag Then
		NewElement = ConditionalAppearanceItem.Fields.Items.Add();
		NewElement.Field = New DataCompositionField("SKU");
	EndIf;
	
	If ItemFound.Свойство("DescriptionFull_Flag") And ItemFound.DescriptionFull_Flag Then
		NewElement = ConditionalAppearanceItem.Fields.Items.Add();
		NewElement.Field = New DataCompositionField("DescriptionFull");
	EndIf;
	
EndProcedure
	
&AtClient
Procedure Yes(Command)
	
	If Items.ListOfNomenclature.CurrentData <> Undefined Then
		Close(Items.ListOfNomenclature.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure No(Command)
	
	Close(True);
	
EndProcedure

&AtClient
Procedure ListOfNomenclatureSelection(Item, SelectedRow, Field, StandardProcessing)
	
	Close(Items.ListOfNomenclature.CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure ReturnCardFill(Command)
	
	Close(Undefined);
	
EndProcedure
//end Bernavski
