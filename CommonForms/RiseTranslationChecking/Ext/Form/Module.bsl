
&AtClient
Function GetIndicationColor()
	
	Return New Color(255, 1, 1);

EndFunction

&AtClient
Procedure SavePreviousAppearanceSettings(Знач CurrentData, PropertiesString)
	
	ItemName = CurrentData.Name;
	ActiveItem = FormOwner.Items.Find(ItemName);
	
	PreviousAppearanceSettings = New Structure(PropertiesString);
	FillPropertyValues(PreviousAppearanceSettings, ActiveItem);
	CurrentData.PreviousAppearanceSettings = PreviousAppearanceSettings;

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Not IsBlankString(Parameters.TreeAddress) Then
		vtrItemsTree = GetFromTempStorage(Parameters.TreeAddress);
		ValueToFormAttribute(vtrItemsTree, "ItemsTree");
		//ЗаполнитьPreviousTranslation(ItemsTree);
		rowID = GetRowIDByFieldValue(Parameters.ActiveItem, "Name", ItemsTree.GetItems());
		Items.ItemsTree.CurrentRow = rowID;
	EndIf;
	
	Items.ItemsTreeOriginalText.Title = ?(IsBlankString(Items.ItemsTreeOriginalText.Title), "Original text", Items.ItemsTreeOriginalText.Title) + " (" + SessionParameters.RiseSourceLanguage + ")";
	Items.ItemsTreeTranslation.Title = ?(IsBlankString(Items.ItemsTreeTranslation.Title), "Translation", Items.ItemsTreeTranslation.Title) + " (" + SessionParameters.RiseTargetLanguage + ")";
	If IsBlankString(SessionParameters.RiseAdditionalLanguage) Then
		Items.ItemsTreeAdditionalLanguage.Visible = False;
	Else
		Items.ItemsTreeAdditionalLanguage.Title = ?(IsBlankString(Items.ItemsTreeAdditionalLanguage.Title), "Additional language", Items.ItemsTreeAdditionalLanguage.Title) + " (" + SessionParameters.RiseAdditionalLanguage + ")";
	EndIf;
EndProcedure

&AtClient
Function TranslationChanged(Root)
	For each row Из Root.GetItems() Do
		If row.PreviousTranslation <> row.Translation Then
			Return True;
		EndIf;
		Changed = TranslationChanged(row);
		If Changed Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

&AtServer
Function GetRowIDByFieldValue(FieldValue, FieldName, TreeItems, StopSearch = False, RowID = Undefined) Экспорт
    
    For each TreeItem ИЗ TreeItems Do
        
        If StopSearch Then
            Return RowID;
        EndIf;
        
        If TreeItem[FieldName] = FieldValue Then
            RowID = TreeItem.GetID();
            StopSearch = True;
            Return RowID;
        EndIf;
        
        TreeItemsNew = TreeItem.GetItems();
        
        If TreeItemsNew.Count() > 0 Then
            RowID = GetRowIDByFieldValue(FieldValue, FieldName, TreeItemsNew, StopSearch, RowID);
        EndIf;
        
	EndDo;
	
	Return RowID;
    
EndFunction

&AtClient
Procedure RestorePreviousAppearanceSettings(Знач CurrentData)
	
	ItemName = CurrentData.Name;
	ActiveItem = FormOwner.Items.Find(ItemName);
	
	If CurrentData.PreviousAppearanceSettings <> Undefined Then
		FillPropertyValues(ActiveItem, CurrentData.PreviousAppearanceSettings);
		CurrentData.PreviousAppearanceSettings = Undefined;
	EndIf; 

EndProcedure

&AtClient
Procedure ActiveItemIndication()
	
	CurrentRow = Items.ItemsTree.CurrentRow;
	CurrentData = Items.ItemsTree.CurrentData;
	If CurrentData = Undefined Then
		AttachIdleHandler("ActiveItemIndication", 2, True);
		Return;
	EndIf;
	
	ItemName = CurrentData.Name;
	ActiveItem = FormOwner.Items.Find(ItemName);
	If ActiveItem = Undefined Then
		AttachIdleHandler("ActiveItemIndication", 2, True);
		Return;
	EndIf;
	
	If TypeOf(ActiveItem) = Type("FormButton") Then
		Marker = "<!>";
		If Find(ActiveItem.Title, Marker) = 1 Then
			RestorePreviousAppearanceSettings(CurrentData); 
		Else
			SavePreviousAppearanceSettings(CurrentData, "Title, Check");
			ActiveItem.Title = Marker + ActiveItem.Title;
			ActiveItem.Check = Not ActiveItem.Check;
		EndIf;
		
	ElsIf TypeOf(ActiveItem) = Type("FormField") Then
		FormOwner.CurrentItem = ActiveItem;
		If True Или CurrentRow.Visible Then
			Marker = GetIndicationColor();
			
			fBackColor = True;
			fTitleBackColor = True;
			fBorderColor = True;
			stAttributes = New Structure("BackColor, TitleBackColor, BorderColor");
			FillPropertyValues(stAttributes, ActiveItem);
			strAttributes = "";
			
			For each attr in stAttributes Do
				If attr.Value <> Undefined Then
					strAttribute = attr.Key;
					strAttributes = strAttributes + strAttribute + ",";
				EndIf;
			EndDo;
			
			If ActiveItem[strAttribute] = Marker Then
				RestorePreviousAppearanceSettings(CurrentData); 
			Else
				SavePreviousAppearanceSettings(CurrentData, strAttributes);
				For each attr in stAttributes Do
					If attr.Value <> Undefined Then
						ActiveItem[attr.Key] = Marker;
					EndIf;
				EndDo;
			EndIf; 
		EndIf; 
	ElsIf TypeOf(ActiveItem) = Type("FormGroup") Then
		If ActiveItem.Type = FormGroupType.ColumnGroup Then
			Marker = GetIndicationColor();
			If ActiveItem.TitleBackColor = Marker Then
				RestorePreviousAppearanceSettings(CurrentData); 
			Else
				SavePreviousAppearanceSettings(CurrentData, "TitleBackColor");
				ActiveItem.TitleBackColor = Marker;
			EndIf; 
		ElsIf ActiveItem.Type <> FormGroupType.Pages Then
			Marker = GetIndicationColor();
			If ActiveItem.BackColor = Marker Then
				RestorePreviousAppearanceSettings(CurrentData); 
			Else
				SavePreviousAppearanceSettings(CurrentData, "BackColor");
				ActiveItem.BackColor = Marker;
			EndIf; 
		EndIf;
	Else
		If True Или CurrentRow.Visible Then
			FormOwner.CurrentItem = ActiveItem;
			PropertyName = "BackColor";
			Marker = GetIndicationColor();
			If ActiveItem[PropertyName] = Marker Then
				RestorePreviousAppearanceSettings(CurrentData); 
			Else
				SavePreviousAppearanceSettings(CurrentData, PropertyName);
				ActiveItem[PropertyName] = Marker;
			EndIf; 
		EndIf; 
	EndIf; 
	AttachIdleHandler("ActiveItemIndication", 0.5, True);
	
EndProcedure

&AtClient
Procedure RestoreAppearanceSettings(Root = Undefined)
	If Root = Undefined Then
		Root = ItemsTree;
	EndIf;
	
	For each TreeItem Из Root.GetItems() Do
		RestorePreviousAppearanceSettings(TreeItem); 
		RestoreAppearanceSettings(TreeItem);
	EndDo;
	
EndProcedure

&AtServer
Procedure SaveTranslation(TreeItems, Error)
	For each TreeItem Из TreeItems Do
		If TreeItem.Translation <> TreeItem.PreviousTranslation Then
			If RiseTranslation.SetTranslation(TreeItem.Arrange, TreeItem.Translation) Then
				TreeItem.PreviousTranslation = TreeItem.Translation;
			Else
				Error = True;
			EndIf;
		EndIf;
		SaveTranslation(TreeItem.GetItems(), Error);
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteOnServer()
	Error = False;
	SaveTranslation(ItemsTree.GetItems(), Error);
	If Not Error Then
		Modified = False;
	EndIf;
EndProcedure

&AtClient
Procedure Write(Command)
	WriteOnServer();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	AttachIdleHandler("ActiveItemIndication", 0.2, True);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	If TranslationChanged(ItemsTree) И Not ForceClose Then
		Cancel = True;
		ShowQueryBox(New NotifyDescription("BeforeCloseEnd", ThisObject), NStr("ru = 'Данные были изменены. Сохранить изменения?'; en = 'The data have been changed. Save changes?'"), QuestionDialogMode.YesNoCancel, 30, DialogReturnCode.Yes);
	EndIf;
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Экспорт
	
	If Result = DialogReturnCode.Yes Then
		WriteOnServer();
		Close();
	ElsIf Result = DialogReturnCode.No Then
		ForceClose = True;
		Close();
	EndIf;

EndProcedure

&AtClient
Procedure ShowOnlyModified(Command)
	OnlyModified = Not OnlyModified;
	Items.FormOnlyModified.Check = OnlyModified;
EndProcedure

&AtClient
Procedure ShowCommandBars(Command)
	CommandBars = Not CommandBars;
	Items.FormShowCommandBars.Check = CommandBars;
EndProcedure

&AtClient
Procedure ShowContextMenu(Command)
	ShowContextMenu = Not ShowContextMenu;
	Items.FormShowContextMenu.Check = ShowContextMenu;
EndProcedure

&AtClient
Procedure ShowOnlyUntranslated(Команда)
	OnlyUntranslated = Not OnlyUntranslated;
	Items.FormOnlyUntranslated.Check = OnlyUntranslated;
EndProcedure

&AtClient
Procedure OnClose()
	RestoreAppearanceSettings();
EndProcedure


&AtClient
Procedure ItemsTreeOnActivateRow(Item)
	RestoreAppearanceSettings();
EndProcedure

