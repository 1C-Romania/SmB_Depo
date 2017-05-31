
///////////////////////////////////////////////////////////////////////////////////////////////////////////
/// FUNCTIONS FOR WORKING WITH MECHANICS OF FINANCIAL YEAR

Function GetMonthsDiff(nBegDate, nEndDate) Export
	
	BegDate = nBegDate;
	EndDate = nEndDate;
	
	MonthsDiff = 0;
	
	While BegDate < EndDate Do		
		MonthsDiff = MonthsDiff + 1;
		BegDate = AddMonth(BegDate, 1);
	EndDo;
	
	Return MonthsDiff;
	
EndFunction

Function GetFinancialYear(DocDate) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	FinancialYears.Ref
	             |FROM
	             |	Catalog.FinancialYears AS FinancialYears
	             |WHERE
	             |	FinancialYears.DateFrom <= &DocDate
	             |	AND ENDOFPERIOD(FinancialYears.DateTo, DAY) >= &DocDate";
	
	Query.SetParameter("DocDate", DocDate);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Ref;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function GetBegOfFinancialYear(DocDate) Export
	Ref = GetFinancialYear(DocDate);
	
	If Ref = Undefined Then
		BegOfFinancialYear = '00010101';
	Else
		BegOfFinancialYear = Ref.DateFrom;
	EndIf;
	
	return BegOfFinancialYear;
EndFunction

Function GetEndOfFinancialYear(DocDate) Export
	Ref = GetFinancialYear(DocDate);
	
	If Ref = Undefined Then
		EndOfFinancialYear = '00010101';
	Else
		EndOfFinancialYear = Ref.DateTo;
	EndIf;
	
	return EndOfFinancialYear;
EndFunction

// Check if ExtDimensions are allowed for Account
Procedure AllowAccountsExtDimensions(Account, ExtDimensionName = "ExtDimension", Controls, ParentItemNameForManagedForm = "") Export
	
	MaxExtraDimension = Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount;
	
	For Counter = 1 To MaxExtraDimension Do
		
		// get label control
		LabelControl = Controls.Find("Label" + ExtDimensionName + Counter);
		
		If Not ValueIsFilled(Account) Or Counter > Account.ExtDimensionTypes.Count() Then
			
			Controls[ParentItemNameForManagedForm + ExtDimensionName + Counter].Enabled = False;
			#If ThickClientOrdinaryApplication Then
				If LabelControl <> Undefined Then
					LabelControl.Value = NStr("en = 'Extra dimension '; pl = 'Analityka '") + Counter + ":";
					LabelControl.Enabled = False;
				EndIf;
			#Else
				Controls[ParentItemNameForManagedForm + ExtDimensionName + Counter].Title = NStr("en = 'Extra dimension '; pl = 'Analityka '") + Counter;
			#EndIF
		Else
			Controls[ParentItemNameForManagedForm + ExtDimensionName + Counter].Enabled = True; 
			ExtDimensionType = Account.ExtDimensionTypes[Counter-1].ExtDimensionType;			
			#If ThickClientOrdinaryApplication Then
				If LabelControl <> Undefined Then
					LabelControl.Value = String(ExtDimensionType) + ":";
					LabelControl.Enabled = True;
				EndIf;
			#Else
				Controls[ParentItemNameForManagedForm + ExtDimensionName + Counter].Title = String(ExtDimensionType);
			#EndIF
			
		EndIf;
		
	EndDo;
	
EndProcedure	


//////////////////////////////////////////////////////////////////////////////////////////////////
///// Functions working with Bookkeeping templates 
Function GetAvailableListOfDocumentsToBookkeepingPosting(All = False) Export
	
	ValueList = New ValueList;
	
	If Not All Then
		
		Query = New Query;
		Query.Text = "SELECT
		             |	BookkeepingPostingSettings.Object AS Ref
		             |FROM
		             |	InformationRegister.BookkeepingPostingSettings AS BookkeepingPostingSettings
		             |WHERE
		             |	BookkeepingPostingSettings.BookkeepingPostingType = VALUE(Enum.BookkeepingPostingTypes.DontPost)";
		
		TableDontPost = Query.Execute().Unload();
		
	EndIf;
	
	AvailableTypes = Metadata.InformationRegisters.BookkeepingPostingSettings.Dimensions.Object.Type;
	
	For Each MetadataObject In Metadata.Documents Do
		
		EmptyRef = Documents[MetadataObject.Name].EmptyRef();
		
		If AvailableTypes.ContainsType(TypeOf(EmptyRef)) And (All Or TableDontPost.Find(EmptyRef, "Ref") = Undefined) Then
			ValueList.Add(Documents[MetadataObject.Name].EmptyRef(),MetadataObject.Synonym);
		EndIf;
		
	EndDo;
	
	ValueList.SortByPresentation();
	
	Return ValueList;
	
EndFunction

Function GetListOfAvailableBookkeepingOperationTemplates(DocumentRef) Export
	
	ValueList = New ValueList();
		
	MetadataObject = DocumentRef.Metadata();
	QueryTextTemplate = " SELECT ALLOWED * " + Chars.LF+
	" FROM Document." + MetadataObject.Name + " AS DataSource";
	
	Query = New Query();
	Query.Text = "SELECT
	             |	BookkeepingOperationsTemplates.Ref,
	             |	BookkeepingOperationsTemplates.Filter,
	             |	BlockedBookkeepingOperationTemplates.Template
	             |FROM
	             |	Catalog.BookkeepingOperationsTemplates AS BookkeepingOperationsTemplates
	             |		LEFT JOIN InformationRegister.BlockedBookkeepingOperationTemplates AS BlockedBookkeepingOperationTemplates
	             |		ON BookkeepingOperationsTemplates.Ref = BlockedBookkeepingOperationTemplates.Template
	             |WHERE
	             |	BookkeepingOperationsTemplates.DocumentBase = &DocumentBase
	             |	AND BlockedBookkeepingOperationTemplates.Template IS NULL";
		
	Query.SetParameter("DocumentBase",Documents[MetadataObject.Name].EmptyRef());
	Selection = Query.Execute().Select();
	
	DCS = New DataCompositionSchema;
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	TemplateComposer = New DataCompositionTemplateComposer;	
	
	DataSource = TemplateReports.AddLocalDataSource(DCS);
	DataSet = TemplateReports.AddDataSetQuery(DCS.DataSets, DataSource);
	DataSet.Query = QueryTextTemplate;
	
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCS));
	NewGroup = DataCompositionSettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	NewGroupField = NewGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	NewGroupField.Field = New DataCompositionField("Ref");
	
	TempQuery = New Query();
	TempQuery.Text = "";
	
	i = 0;
	TemplatesToQueryArray = New Array();
	
	While Selection.Next() Do	
	
		FilterAsXML = Selection.Filter.Get();
		
		If IsBlankString(FilterAsXML) Then
			
			ValueList.Add(Selection.Ref);
			Continue;
			
		Else	
			
			TemplateReports.CopyItems(DataCompositionSettingsComposer.Settings.Filter,Common.GetObjectFromXML(FilterAsXML,Type("DataCompositionFilter")),True,True);
			TemplateReports.AddFilter(DataCompositionSettingsComposer,"Ref",DocumentRef);
			CompositionTemplate = TemplateComposer.Execute(DCS, DataCompositionSettingsComposer.Settings,,,Type("DataCompositionValueCollectionTemplateGenerator"));
			
			iQuery = CompositionTemplate.DataSets.DataSet1.Query;
			For Each Parameter In CompositionTemplate.ParameterValues Do
				TempQuery.SetParameter("T"+i+Parameter.Name,Parameter.Value);
				iQuery = StrReplace(iQuery,"&"+Parameter.Name,"&T"+i+Parameter.Name);
			EndDo;	
			
			TempQuery.Text = TempQuery.Text + iQuery + ";";
			i=i+1;
			
			TemplatesToQueryArray.Add(Selection.Ref);
			
		EndIf;
				
	EndDo;	
	
	If NOT IsBlankString(TempQuery.Text) Then
		
		TempQueryResultArray = TempQuery.ExecuteBatch();
		
		i=0;
		For Each TempQueryResultArrayItem In TempQueryResultArray Do
			
			If Not TempQueryResultArrayItem.IsEmpty() Then
				
				ValueList.Add(TemplatesToQueryArray[i]);
				
			EndIf;	
			
			i=i+1;
			
		EndDo;	
		
	EndIf;	
	
	Return ValueList;
	
EndFunction	

Function GetStatusOfBookkeepingOperationTemplatesForDocument(BookkeepingOperationsTemplates, DocumentRef) Export
	
	If NOT BookkeepingOperationsTemplates.IsEmpty() AND DocumentRef <> Undefined Then
		ValueList = GetListOfAvailableBookkeepingOperationTemplates(DocumentRef);
		Return (ValueList.FindByValue(BookkeepingOperationsTemplates)<>Undefined);
	EndIf;
	
	Return FALSE;
	
EndFunction

// DocumentRef - Document for which should be created Bookkeeping operation
// BookkeepingOperationsTemplate - Ret value, if was found matched bookkeeping schema then returns it, else Undefined
// Return value - 0 - No schemas found
//				  1 - Ok, was found one matched schema
//				  2 - Two or more found with filter
//				  3 - Two or more found without filter
Function GetRecommendSchemaForDocument(DocumentRef, BookkeepingOperationsTemplate, CheckExistingBO = True) Export
	
	If CheckExistingBO Then
		BookkeepingOperation = Documents.BookkeepingOperation.FindByAttribute("DocumentBase", DocumentRef);
		If ValueIsFilled(BookkeepingOperation) Then
			BookkeepingOperationsTemplate = BookkeepingOperation.BookkeepingOperationsTemplate;
			Return 1;
		EndIf;
	EndIf;
	
	ValueList = GetListOfAvailableBookkeepingOperationTemplates(DocumentRef);
	CountOfSchema = ValueList.Count();
	If CountOfSchema = 1 Then
		BookkeepingOperationsTemplate = ValueList[0].Value;
		//Exists one matching schema
		Return 1;	
	ElsIf CountOfSchema > 1 Then
		CountOfSchemaWithFilter = 0;
		CountOfSchemaWithoutFilter = 0;
		For each Item in ValueList do
			
			IsFilter = FALSE;
			FilterAsXML = Item.Value.Filter.Get();
			If FilterAsXML <> "" Then
				FilterAsObject = Common.GetObjectFromXML(FilterAsXML,Type("DataCompositionFilter"));
				For each FilterItem in FilterAsObject.Items do
					If  FilterItem.Use Then
						IsFilter = TRUE;	
					EndIf;
				EndDo;
			EndIf;			
			
			If  IsFilter Then
				CountOfSchemaWithFilter = CountOfSchemaWithFilter + 1;
				SchemaWithFilter = Item.Value;
			Else
				CountOfSchemaWithoutFilter  = CountOfSchemaWithoutFilter + 1;
				SchemaWithoutFilter = Item.Value;
			EndIf;
		EndDo;
		
		If CountOfSchemaWithFilter = 1 Then
			BookkeepingOperationsTemplate = SchemaWithFilter;
			//Exists one matching schema with filter
			Return 1;			
		ElsIf CountOfSchemaWithFilter = 0 and CountOfSchemaWithoutFilter = 1 Then
			BookkeepingOperationsTemplate =SchemaWithoutFilter;
			//Exists one matching schema without filter
			Return 1;			
		ElsIf CountOfSchemaWithFilter > 1 Then
			//Exists more then one schema with filter
			Return 2;
		ElsIf CountOfSchemaWithFilter = 0 and CountOfSchemaWithoutFilter > 1 Then
			//Exists more then one schema without filter
			Return 3;
		EndIf;
		
	ElsIf CountOfSchema = 0 Then
		// Not find any matching schema
		Return 0;
	EndIf;
		
EndFunction

// Function for catalogs with bookkeeping information registers
#If Client Then

Procedure BeforeOpenForCatalogsWithBookkeepingInformationRegisters(IsOpeningViaCatalog,Cancel, ThisForm, FormOwner, InfomationRegisterName, ResourcesForQuery, PeriodFromChoiceList = Undefined, PeriodBeforeChoice = Undefined, SelectionAction = False ) Export
	
	NewRowDefenition = "NewRecord";
	NewRowAlias = Nstr("en='New record';pl='Nowy wpis';ru='Новая запись'");
	
	// If open from catalogs object	
	If IsOpeningViaCatalog Then 
		
		ResourcesForQuery = "";
		
		InfomationRegisterName = StrReplace(ThisForm.InformationRegisterRecordManager, "InformationRegisterRecordManager.", "");
		
		MetaDataInformationRegister = Metadata.InformationRegisters[InfomationRegisterName];
		
		If ValueIsFilled(ThisForm.Object) Then 
			CatalogsRef = ThisForm.Object;
		Else
			Try
				CatalogsRef = FormOwner.Ref;
			Except
				If FormOwner.Controls.CatalogList.CurrentData <> Undefined Then
					CatalogsRef = FormOwner.Controls.CatalogList.CurrentData.Ref;
				Else
					Cancel = True;
					Return;
				EndIf;
			EndTry;
		EndIf;
		
		//Fill form
		If Not SelectionAction Then
			UserListBoxWidth = 120;
			
			ThisForm.Width = ThisForm.Width + UserListBoxWidth ;
			ThisForm.Controls.FormActions.Width = ThisForm.Controls.FormActions.Width + UserListBoxWidth ;
			ThisForm.Controls.FormMainActions.Width = ThisForm.Controls.FormMainActions.Width + UserListBoxWidth ;
			
			
			SplitterHeader1 = ThisForm.Controls.Add(Type("Splitter"),"SplitterHeader1",False,ThisForm.Panel);
			ThisForm.Controls.SplitterHeader1.Orientation = Orientation.Vertical;
			ThisForm.Controls.SplitterHeader1.Width = 4;
			ThisForm.Controls.SplitterHeader1.Height = ThisForm.Height - 58;
			ThisForm.Controls.SplitterHeader1.Top = 29;
			ThisForm.Controls.SplitterHeader1.Left = UserListBoxWidth + 10;
			ThisForm.Controls.SplitterHeader1.SetLink(ControlEdge.Top, ThisForm.Controls.FormActions, ControlEdge.Top);
			ThisForm.Controls.SplitterHeader1.SetLink(ControlEdge.Bottom, ThisForm.Controls.FormMainActions, ControlEdge.Bottom);
			
			
			ThisForm.Controls.SplitterHeader1.Visible = True;
			ThisForm.Controls.SplitterHeader1.Transparent = False;
			
			ListBox1 = ThisForm.Controls.Add(Type("ListBox"),"ListBox1",False,ThisForm.Panel);
			ProcessingPressing = New Action("ListBox1Selection");
			ThisForm.Controls.ListBox1.SetAction ("Selection", ProcessingPressing);
			ThisForm.Controls.ListBox1.Left = 8;
			ThisForm.Controls.ListBox1.Top = 33;
			ThisForm.Controls.ListBox1.Width = UserListBoxWidth;
			ThisForm.Controls.ListBox1.Height = ThisForm.Height - 66;
			
			
			ThisForm.Controls.ListBox1.Visible = True;
			
			ThisForm.Controls.ListBox1.SetLink(ControlEdge.Left,ThisForm.Panel, ControlEdge.Left);
			ThisForm.Controls.ListBox1.SetLink(ControlEdge.Right,ThisForm.Controls.SplitterHeader1, ControlEdge.Left);
			ThisForm.Controls.ListBox1.SetLink(ControlEdge.Bottom,ThisForm.Controls.FormMainActions, ControlEdge.Bottom);
			ThisForm.Controls.ListBox1.SetLink(ControlEdge.Bottom,ThisForm.Panel, ControlEdge.Bottom);
			ThisForm.Controls.ListBox1.SetLink(ControlEdge.Top,ThisForm.Controls.FormActions, ControlEdge.Top);
			
			
			
			ThisForm.Controls.LabelPeriod.Left = UserListBoxWidth + 20;
			ThisForm.Controls.LabelPeriod.SetLink(ControlEdge.Left, ThisForm.Controls.SplitterHeader1, ControlEdge.Right);
			ThisForm.Controls.Period.Width = ThisForm.Controls.Period.Width - UserListBoxWidth - 20;
			ThisForm.Controls.Period.Left = ThisForm.Controls.Period.Left + UserListBoxWidth + 20;
			ThisForm.Controls.Period.SetLink(ControlEdge.Right, ThisForm.Panel, ControlEdge.Right);
			ThisForm.Controls.Period.SetLink(ControlEdge.Left, ThisForm.Controls.SplitterHeader1, ControlEdge.Right);
			
			ThisForm.Controls.LabelObject.Left = UserListBoxWidth + 20;
			ThisForm.Controls.LabelObject.SetLink(ControlEdge.Left, ThisForm.Controls.SplitterHeader1, ControlEdge.Right);
			ThisForm.Controls.Object.Width = ThisForm.Controls.Object.Width - UserListBoxWidth - 20;
			ThisForm.Controls.Object.Left = ThisForm.Controls.Object.Left + UserListBoxWidth + 20;
			ThisForm.Controls.Object.SetLink(ControlEdge.Right, ThisForm.Panel, ControlEdge.Right);
			ThisForm.Controls.Object.SetLink(ControlEdge.Left, ThisForm.Controls.SplitterHeader1, ControlEdge.Right);
			
			
			For each Resources in MetaDataInformationRegister.Resources do
				Try
					ThisForm.Controls["Label"+Resources.Name].Left = UserListBoxWidth + 20;
					ThisForm.Controls["Label"+Resources.Name].SetLink(ControlEdge.Left, ThisForm.Controls.SplitterHeader1, ControlEdge.Right);
				Except
					
				EndTry;
				
				ThisForm.Controls[Resources.Name].Width = ThisForm.Controls[Resources.Name].Width - UserListBoxWidth - 20;
				ThisForm.Controls[Resources.Name].Left = ThisForm.Controls[Resources.Name].Left + UserListBoxWidth + 20;
				ThisForm.Controls[Resources.Name].SetLink(ControlEdge.Right, ThisForm.Panel, ControlEdge.Right);
				ThisForm.Controls[Resources.Name].SetLink(ControlEdge.Left, ThisForm.Controls.SplitterHeader1, ControlEdge.Right);
			EndDo;
		EndIf;									
		//Fill from
		
		
		//Fill ListBox1
		ResourcesForQuery = "	"+ InfomationRegisterName + "SliceLast.Period"+
		","+ InfomationRegisterName + "SliceLast.Object";
		
		
		Query = new Query;
		Query.Text = "SELECT " + 
		ResourcesForQuery +
		" FROM  
		|	InformationRegister."+ InfomationRegisterName + " AS " + InfomationRegisterName + "SliceLast WHERE Object.Ref = &Ref";
		
		Query.SetParameter("Ref",CatalogsRef);
		Result = Query.Execute();
		Selection = Result.Select();
		ThisForm.Controls.ListBox1.Value.Clear();
		While Selection.Next() do				
			ThisForm.Controls.ListBox1.Value.Add(Selection.Period);		
		EndDo;	
		ThisForm.Controls.ListBox1.Value.Add(NewRowDefenition,NewRowAlias);
		If SelectionAction and PeriodFromChoiceList<> NewRowDefenition Then
			List = ThisForm.Controls.ListBox1.Value;
			ThisForm.Controls.ListBox1.CurrentRow = List.FindByValue(PeriodFromChoiceList);
			PeriodForQuery = PeriodFromChoiceList;
			ThisForm.Controls.Period.ReadOnly = True;
			ThisForm.Controls.Object.ReadOnly = True;
			ThisForm.Modified = False;
		Else
			If PeriodFromChoiceList = NewRowDefenition Then
				ThisForm.Controls.Period.ReadOnly = False;
				ThisForm.Controls.Object.ReadOnly = False;	
				List = ThisForm.Controls.ListBox1.Value;
				ThisForm.Controls.ListBox1.CurrentRow = List.FindByValue(NewRowDefenition);
			Else
				ThisForm.Controls.Period.ReadOnly = True;
				ThisForm.Controls.Object.ReadOnly = True;					
				ThisForm.Modified = False;
			EndIf;
			
			PeriodForQuery = BegOfDay(CurrentDate());
		EndIf;
		//Fill ListBox1
		
		// Set resources to filled from informatin registers to catalog form
		For each Resources in MetaDataInformationRegister.Resources do
			ResourcesForQuery = ResourcesForQuery +","+ InfomationRegisterName + "SliceLast." + Resources.Name;
		EndDo;
		
		
		If ValueIsFilled(CatalogsRef) Then					
			
			Query = new Query;
			Query.Text = "SELECT" + 
			ResourcesForQuery +
			" FROM  
			|	InformationRegister."+ InfomationRegisterName + " AS " + InfomationRegisterName + "SliceLast WHERE Object.Ref = &Ref AND Period>= &Period";
			
			Query.SetParameter("Ref",CatalogsRef);
			Query.SetParameter("Period",PeriodFromChoiceList);
			Result = Query.Execute();
			Selection = Result.Select();
			If Selection.Next() Then
				
				// Fill information register from for catalog
				ThisForm.Period = Selection.Period;
				ThisForm.Object = Selection.Object;
				For each Resources in MetaDataInformationRegister.Resources do
					ThisForm[Resources.Name] = Selection[Resources.Name];
				EndDo;
				
				//Mark current row
				List = ThisForm.Controls.ListBox1.Value;
				ThisForm.Controls.ListBox1.CurrentRow = List.FindByValue(ThisForm.Period);
				//Mark current row
				
			Else
				// Fill information register from for catalog as new state
				ThisForm.Period = CurrentDate();
				ThisForm.Object = CatalogsRef.Ref;
				ThisForm.Controls.Object.ReadOnly = True;
				ThisForm.Modified = False;
			EndIf;
			
		EndIf;
		
		
		If PeriodFromChoiceList = NewRowDefenition Then
			
			ThisForm.Period = CurrentDate();
			ThisForm.Object = CatalogsRef;
			ThisForm.Controls.Object.ReadOnly = True;
			For each Resources in MetaDataInformationRegister.Resources do
				ThisForm[Resources.Name] = Undefined;
			EndDo;
			
		Else
			ThisForm.Modified = False;
		EndIf;
		
	EndIf;
	
EndProcedure

Function UserSaveForCatalogsWithBookkeepingInformationRegisters (IsOpeningViaCatalog, ThisForm, FormOwner, InfomationRegisterName, ResourcesForQuery) Export
	
	If IsOpeningViaCatalog Then 
		
		If ValueIsFilled(ThisForm.Object) Then 
			CatalogsRef = ThisForm.Object;
		Else
			Try
				CatalogsRef = FormOwner.Ref;
			Except
				CatalogsRef = FormOwner.Controls.CatalogList.CurrentData.Ref;
			EndTry;
		EndIf;

		If ValueIsFilled(CatalogsRef) Then
			Query = new Query;
			Query.Text = "SELECT" + 
			ResourcesForQuery +
			" FROM  
			|	InformationRegister."+ InfomationRegisterName + " AS " + InfomationRegisterName + "SliceLast WHERE Object.Ref = &Ref AND Period = &Period";
						
			Query.SetParameter("Ref",CatalogsRef);
			Query.SetParameter("Period",ThisForm.Period);
			Result = Query.Execute();
			Selection = Result.Select();
			If Selection.Next() and ThisForm.Modified()=True Then
					Try
						ThisForm.Write(True);
						ThisForm.Modified = False;
					Except
						ShowMessageBox(, Nstr("en='Error during the writeing';pl='Błąd podczas zapisu.'"));
					EndTry;
				
			Else
					Try					   
						ThisForm.Write(True);	
						ThisForm.Modified = False;
					Except
						ShowMessageBox(, Nstr("en='Error during the writeing';pl='Błąd podczas zapisu.'"));
					EndTry;					
			EndIf;				
		EndIf;
	Else
		ThisForm.Write(False);	
	EndIf;
	
	If Not ThisForm.FormOwner = Undefined Then
		If Not ThisForm.CloseOnChoice Then
			ThisForm.NotifyChoice(ThisForm.InformationRegisterRecordManager);
		EndIf;
	EndIf;

EndFunction

Function GetBookkeepingOperationTemplateForDocument(Document) Export
	
	Query = New Query();
	Query.Text =  "SELECT
	              |	BookkeepingPostedDocuments.BookkeepingOperation
	              |FROM
	              |	InformationRegister.BookkeepingPostedDocuments AS BookkeepingPostedDocuments
	              |WHERE
	              |	BookkeepingPostedDocuments.Document = &Document
	              |	AND BookkeepingPostedDocuments.BookkeepingOperation <> VALUE(Document.BookkeepingOperation.EmptyRef)";
	Query.SetParameter("Document",Document);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		ShowMessageBox(, Nstr("en='Document doesnot have bookkeeping operation';pl='Dokument nie ma DK'"));
		Return Undefined;
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Selection.BookkeepingOperation.GetForm().Open();
		Return Selection.BookkeepingOperation;
	EndIf;	
	
EndFunction	

#EndIf