
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Ref = Undefined;
	If NOT Parameters.Property("Ref",Ref) Then
		Cancel = True;
	ElsIf Ref.IsFolder Then
		CommonAtClientAtServer.NotifyUser(Nstr("en='There is no settings for folders';pl='Brak ustawień dla folderów';ru='Настройки для папок не были проведены.'"));
		Cancel = True;
	EndIf;
	
	PredefinedArray = New Array;
	PredefinedArray.Add("StandardAttributes");
	PredefinedArray.Add("Dimensions");
	PredefinedArray.Add("Resources");
	
	FieldsOrder = New Array();
	// Don't reorder Object and Period fields!!!
	If TypeOf(Ref) = Type("CatalogRef.BankAccounts") Then
		MetadataName = "FinancialBankAccounts";
	// by Pavlo add begin
	ElsIf TypeOf(Ref) = Type("CatalogRef.AccrualAndDeductionKinds") Then
		MetadataName = "FinancialAccrualAndDeductionKinds";	
	ElsIf TypeOf(Ref) = Type("CatalogRef.FinancialCounterpartyGroups") Then
		MetadataName = "FinancialCounterpartiesGroups";	
	ElsIf TypeOf(Ref) = Type("CatalogRef.FinancialProductsAndServicesGroups") Then
		MetadataName = "FinancialProductsAndServicesGroups";	
	ElsIf TypeOf(Ref) = Type("CatalogRef.VATRates") Then
		MetadataName = "FinancialVATRates";	
	ElsIf TypeOf(Ref) = Type("CatalogRef.PettyCashes") Then
		MetadataName = "FinancialPettyCashes";	
	// by Pavlo add end	
	EndIf;	
	FieldsOrder.Insert(0,"Object");
	FieldsOrder.Insert(0,"Period");

	
	RegisterMetadata = Metadata.InformationRegisters[MetadataName];
	ResourcesStructure = New Structure;
	
	NewFormAttributesArray = New Array;
	// using value list for sorting
	FieldsArray = New ValueList;
	
	ResourcesAsString = "";
	NewFormAttributesArrayAdditionalStructure = New Structure;
	For Each PredefinedSet In PredefinedArray Do
		
		For Each Attribute In RegisterMetadata[PredefinedSet] Do
			
			NewFormAttributesArray.Add(New FormAttribute(Attribute.Name,Attribute.Type,,Attribute.Synonym,True));
			FieldsArray.Add(Attribute.Name);
			NewFormAttributesArrayAdditionalStructure.Insert(Attribute.Name, Attribute);
			If PredefinedSet = "Resources" Then
				ResourcesAsString = ResourcesAsString + MetadataName + "." + Attribute.Name + " AS " + Attribute.Name+ ", ";
				ResourcesStructure.Insert(Attribute.Name);
			EndIf;	
			
		EndDo;
		
	EndDo;	

	ResourcesAsString = ResourcesAsString + MetadataName + ".Period AS Period";	
	ThisForm.ChangeAttributes(NewFormAttributesArray);
	
	FieldsArray.SortByValue();
	i=1;
	For Each FielsArrayItem In FieldsArray Do
		If FieldsOrder.Find(FielsArrayItem.Value)=Undefined Then
			FieldsOrder.Add(FielsArrayItem.Value);
		EndIf;	
	EndDo;	
	
	For Each NewAttribute In FieldsOrder Do
		FormField = Items.Add(NewAttribute,Type("FormField"),Items.GroupEditable);
		FormField.DataPath = NewAttribute;
		Attribute = Undefined;
		NewFormAttributesArrayAdditionalStructure.Property(NewAttribute,Attribute);
		FormField.TypeRestriction = Attribute.Type;
		If FormField.TypeRestriction.Types().Count() = 1 
			AND FormField.TypeRestriction.Types()[0] = Type("Boolean") Then
			FormField.Type = FormFieldType.CheckBoxField;
		Else	
			FormField.Type = FormFieldType.InputField;
		EndIf;	
		If FormField.Type = FormFieldType.InputField Then
			If NOT IsBlankString(Attribute.LinkByType.DataPath) Then
				FormField.TypeLink = New TypeLink(Attribute.LinkByType.DataPath,Attribute.LinkByType.LinkItem);
			EndIf;	
			FormField.ChoiceParameterLinks = Attribute.ChoiceParameterLinks;
			FormField.ChoiceParameters = Attribute.ChoiceParameters;
			FormField.AutoMarkIncomplete = (Attribute.FillChecking = FillChecking.ShowError);
		EndIf;
	EndDo;	
	
	NewRowDefinition = "NewRecord";
	NewRowAlias = Nstr("en='New record';pl='Nowy wpis';ru='Новая запись'");
			
	ResourcesForQuery = "";
	ResourcesForQuery = "	"+ MetadataName + "SliceLast.Period"+
		","+ MetadataName + "SliceLast.Object";
		
	Query = new Query;
	Query.Text = "SELECT " + 
	ResourcesForQuery +
		" FROM  
		|	InformationRegister."+ MetadataName + " AS " + MetadataName + "SliceLast WHERE Object.Ref = &Ref";
		
	Query.SetParameter("Ref",Ref);
	Result = Query.Execute();
	Selection = Result.Select();
	PeriodTable.Clear();
	While Selection.Next() Do
		PeriodTable.Add(Selection.Period);
	EndDo;	
	
	
	If Parameters.Property("Period") Then
		
		Items.ListBox1.CurrentRow = PeriodTable.FindByValue(Parameters.Period).GetID();
		SetEditableRow(Items.ListBox1.CurrentRow);
		NewRow = PeriodTable.Add(NewRowDefinition,NewRowAlias,,);
		
	Else 
		
		NewRow = PeriodTable.Add(NewRowDefinition,NewRowAlias,,PictureLib.Change);
		Items.ListBox1.CurrentRow = NewRow.GetID();
		SetEditableRow(Items.ListBox1.CurrentRow);	
		
	EndIf;     	
		
	Items.Object.ReadOnly = True;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateDialog();
EndProcedure

&AtClient
Procedure AfterQueryBoxBeforeClose(Answer, QueryParams) Export 
	If Answer = DialogReturnCode.Yes Then 
		Modified	= False;
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	If Modified Then
		Cancel	= True;
		
		QueryText	= Nstr("en='Are you sure want to close window and cancel modified data ?';pl='Czy napewno chcesz zamknąć okno i anulować wprowadzone dane?';ru='Хотите закрыть диалоговое окно и отменить изменение данных?'");
		Notify		= New NotifyDescription("AfterQueryBoxBeforeClose", ThisObject);
		ShowQueryBox(Notify, QueryText, QuestionDialogMode.YesNo);
	EndIf;	
EndProcedure

&AtClient
Procedure Write(Command)
	
	If Modified Then
		CheckFilling();
		WriteResources();
		
		RetStruct = New Structure("Ref, MetadataName",Ref, MetadataName);
		NotifyChoice(RetStruct);
		
	EndIf;	
	
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	If Modified Then
		Text	= Nstr("en='Are you sure want to cancel modified data?';pl='Czy napewno chcesz anulować wprowadzone dane?';ru='Хотите отменить изменение данных?'");
		Mode	= QuestionDialogMode.YesNo;
		Notify	= New NotifyDescription("AfterQueryCloseCancel", ThisObject,);

		ShowQueryBox(Notify, Text, Mode);
	EndIf;	
EndProcedure

&AtClient
Procedure AfterQueryCloseCancel(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then
    	SetEditableRow(CurrentEditableRowIndex);
    EndIf;

EndProcedure


&AtClient
Procedure ListBox1Selection(Item, SelectedRow, Field, StandardProcessing)
	Text	= Nstr("en='Are you sure want to cancel modified data and edit new data?';pl='Czy napewno chcesz anulować wprowadzone dane i zacząc edycje nowych danych?';ru='Хотите отменить изменение данных и снова начать редактирование?'");
	Mode	= QuestionDialogMode.YesNo;
	
	If Modified Then
		NotifyParameters	= New Structure("SelectedRow", SelectedRow);
		Notify		= New NotifyDescription("AfterQueryListBox1Selection", ThisObject, NotifyParameters);

		ShowQueryBox(Notify, Text, Mode);
	Else
		ListBox1SelectionPart(SelectedRow);
	EndIf;
EndProcedure

&AtClient
Procedure AfterQueryListBox1Selection(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.No Then
    	Return;
	EndIf;
	
	ListBox1SelectionPart(Parameters.SelectedRow);

EndProcedure

&AtClient
Procedure ListBox1SelectionPart(Val SelectedRow)
	
	SetEditableRow(SelectedRow);
	UpdateDialog();

EndProcedure

/////////////////////////////////////////////////////////////////////////

&AtServer
Procedure SetEditableRow(RowIndex)
	
	Items.GroupPages.CurrentPage = Items.GroupEditable;
	PeriodTable.FindByID(CurrentEditableRowIndex).Picture = New Picture;
	
	PeriodTable.FindByID(RowIndex).Picture = PictureLib.Change;
	
	CurrentPeriod = PeriodTable.FindByID(RowIndex).Value;
	CurrentEditableRowIndex = RowIndex;
	
	FillResources(CurrentPeriod);
	Modified = False;
	
EndProcedure

&AtServer
Procedure FillResources(Val Period)
	
	Query = New Query;
	Query.Text = "SELECT " + 
	ResourcesAsString +
	" FROM  
	|	InformationRegister."+ MetadataName + " AS " + MetadataName + " WHERE Object.Ref = &Ref AND Period>= &Period";
	
	Query.SetParameter("Ref",Ref);
	Query.SetParameter("Period",Period);
	Result = Query.Execute();
	IsEmptyResult = Result.IsEmpty();
	Selection = Result.Select();
	Selection.Next();
	For Each ResultColumn In Result.Columns Do
		ThisForm[ResultColumn.Name] = ?(IsEmptyResult,Undefined,Selection[ResultColumn.Name]);
	EndDo;	
	ThisForm["Object"] = Ref;
	
EndProcedure	

&AtServer
Procedure WriteResources()
	
	RecordSet = InformationRegisters[MetadataName].CreateRecordSet();
	RecordSet.Filter.Period.Set(ThisForm.Period);
	RecordSet.Filter.Object.Set(ThisForm.Object);
	RecordSet.Read();
	RecordSet.Clear();
	Record = RecordSet.Add();
	Record.Period = ThisForm.Period;
	Record.Object = ThisForm.Object;
	For Each KeyAndValue In ResourcesStructure Do
		Record[KeyAndValue.Key] = ThisForm[KeyAndValue.Key];
	EndDo;	
	RecordSet.Write();
	
	CurrentRow = PeriodTable.FindByID(CurrentEditableRowIndex);
	If CurrentRow.Value = NewRowDefinition Then
		
		CurrentRow.Presentation = ThisForm.Period;
		CurrentRow.Value = ThisForm.Period;
		CurrentRow.Picture = New Picture;
		PeriodTable.SortByValue();
		NewRow = PeriodTable.Add(NewRowDefinition,NewRowAlias,,PictureLib.Change);	
		Items.ListBox1.CurrentRow = NewRow.GetID();
		SetEditableRow(Items.ListBox1.CurrentRow);
		
	EndIf;	
	
EndProcedure	

&AtClient
Procedure UpdateDialog()
	
	If Items.ListBox1.CurrentData <> Undefined Then
		CurrentDataValue = Items.ListBox1.CurrentData.Value;
		Items.Period.ReadOnly = (CurrentDataValue <> NewRowDefinition);
	EndIf;	
	
EndProcedure


