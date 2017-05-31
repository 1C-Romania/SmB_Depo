#Region FormCommands 

&AtClient
Procedure DefaultFilling(Command)    	
	
	RecordSetCount =  GetRecordSetCount();  
	
	If RecordSetCount > 0 then
		
		Buttons = QuestionDialogMode.YesNo;
		
		NotifyDescription = New NotifyDescription("NotifyFilling",ThisObject);
		            
		ShowQueryBox(NotifyDescription, Nstr("en='All existing settings will be replaced! Are you sure you want to continue?';pl='Wszystkie istniejące ustawienia będą nadpisane! Czy napewno chcesz kontynuować?';ru='Все существующие настройки будут перезаписаны! Вы уверены, что хотите продолжить?'"),Buttons);
			
	Else 
		FillByDefaultFromTemplate();
		Items.List.Refresh();

	EndIf;  	
	
EndProcedure

&AtClient
Procedure NotifyFilling(Result, Parameters)  Export 
	
	If Result = DialogReturnCode.Yes Then
		
		FillByDefaultFromTemplate();
		Items.List.Refresh();

	EndIf; 
	
EndProcedure

&AtServer
Function  GetRecordSetCount() 
	
	RecordSet = InformationRegisters.BookkeepingPostingSettings.CreateRecordSet();
	RecordSet.Read();
	
	Return  RecordSet.Count();
	
EndFunction

&AtServer
Procedure FillByDefaultFromTemplate()
	
	RecordSet = InformationRegisters.BookkeepingPostingSettings.CreateRecordSet();
	RecordSet.Read();

	
	Template = InformationRegisters.BookkeepingPostingSettings.GetTemplate("DefaultFilling");
	
	RecordSet.Clear();
	
	For i =1 To Template.TableHeight Do
		
		DocumentMetadataName = Template.Area(i,1,i,1).Text;
		EnumMetadataName = Template.Area(i,2,i,2).Text;
		
		Try
		
			DocumentEmptyRef = Documents[DocumentMetadataName].EmptyRef();
			EnumRef = Common.GetEnumValueByName(Enums.BookkeepingPostingTypes,EnumMetadataName);
		
		Except
			
			Continue;
		
		EndTry; 
		
		Record = RecordSet.Add();
		Record.Object = DocumentEmptyRef;
		Record.BookkeepingPostingType = EnumRef;
		
	EndDo;
	
	RecordSet.Write();
	
EndProcedure

#EndRegion

#Region FormEventHandlers

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	
	If 	CurrentData 			  <> Undefined AND  
	  	CurrentData.ObjectType    <> Undefined AND 
	   	Left(ObjectsExtensionsAtServer.GetMetadataName(CurrentData.Object),1) <> "_" Then
	   
		ShowMessageBox(, Nstr("en='Row could not be deleted!';pl='Nie można usunąć ten wiersz!';ru='Нельзя удалить данную строку!'"));
		Cancel = True;
		
	EndIf;	
	
EndProcedure 

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	NewRowAvailableDocumentsList = FillValueListOfRemainTypes();
	
	If NewRowAvailableDocumentsList.Count() = 0 Then
		ShowMessageBox(, Nstr("en='Settings for all available document types was already set. To change something - edit existing rows.';pl='Ustawienia dla wszystkich dostępnych typów dokumentów już zostali stworzone. Dla edycji ustawień trzeba edytowac istniejące wierszy.';ru='Настройки проведения были определены для всех доступных типов документов. Для изменения настроек необходимо изменить существующие строки.'"));
		Cancel = True;
	EndIf;	

EndProcedure

&AtServer  
Function FillValueListOfRemainTypes()
	
	ValueList = New ValueList;
	ObjectsValueList = New ValueList;
	AvailableListOfDocumentsToBookkeepingPosting = BookkeepingCommon.GetAvailableListOfDocumentsToBookkeepingPosting(True);     

	RecordSet = InformationRegisters.BookkeepingPostingSettings.CreateRecordSet();
	
	RecordSet.Read();
	ObjectsValueList.LoadValues(RecordSet.UnloadColumn("Object"));
	
	For Each Item In AvailableListOfDocumentsToBookkeepingPosting Do
		If ObjectsValueList.FindByValue(Item.Value) = Undefined Then
			ValueList.Add(Item.Value,Item.Presentation);
		EndIf;	
	EndDo;	
	
	ValueList.SortByPresentation();
	
	Return ValueList;
	
EndFunction	

#EndRegion




