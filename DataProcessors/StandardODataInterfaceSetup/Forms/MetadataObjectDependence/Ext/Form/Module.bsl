
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	MetadataObject = Metadata.FindByFullName(Parameters.FullObjectName);
	
	If CommonUseSTL.ThisIsConstant(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'constant'");
	ElsIf CommonUseSTL.ThisIsCatalog(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'catalog'");
	ElsIf CommonUseSTL.ThisIsDocument(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'document'");
	ElsIf CommonUseSTL.IsSequenceRecordSet(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'sequences'");
	ElsIf CommonUseSTL.IsDocumentJournal(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'document log'");
	ElsIf CommonUseSTL.IsEnum(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'enumeration'");
	ElsIf CommonUseSTL.ThisIsChartOfCharacteristicTypes(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'plan of characteristic types'");
	ElsIf CommonUseSTL.ThisIsChartOfAccounts(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'accounts plan'");
	ElsIf CommonUseSTL.ThisIsChartOfCalculationTypes(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'plan of calculation types'");
	ElsIf CommonUseSTL.ThisIsInformationRegister(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'information register'");
	ElsIf CommonUseSTL.ThisIsAccumulationRegister(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'accumulation register'");
	ElsIf CommonUseSTL.IsAccountingRegister(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'accounting register'");
	ElsIf CommonUseSTL.ThisIsCalculationRegister(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'calculation register'");
	ElsIf CommonUseSTL.IsRecalculationRecordSet(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'recalculation'");
	ElsIf CommonUseSTL.ThisIsBusinessProcess(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'business-process'");
	ElsIf CommonUseSTL.ThisIsTask(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'task'");
	ElsIf CommonUseSTL.ThisIsExchangePlan(MetadataObject) Then
		ObjectTypePresentation = NStr("en = 'exchange plan'");
	EndIf;
	
	If Parameters.Insert Then
		
		Items.GroupPagesHeader.CurrentPage = Items.GroupPageHeaderAdd;
		Items.GroupPagesFooter.CurrentPage = Items.GroupPageFooterAdd;
		Items.DecorationTitleHeaderAdd.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			Items.DecorationTitleHeaderAdd.Title,
			ObjectTypePresentation,
			MetadataObject.Presentation()
		);
		
	Else
		
		Items.GroupPagesHeader.CurrentPage = Items.GroupHeaderPageDelete;
		Items.GroupPagesFooter.CurrentPage = Items.GroupFooterPageDelete;
		Items.DecorationTitleHeaderDelete.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			Items.DecorationTitleHeaderDelete.Title,
			ObjectTypePresentation,
			MetadataObject.Presentation()
		);
		
	EndIf;
	
	ThisObject.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		ThisObject.Title, MetadataObject.Presentation());
	
	// Filling of tree
	
	Tree = New ValueTree();
	
	Tree.Columns.Add("DescriptionFull", New TypeDescription("String"));
	Tree.Columns.Add("Presentation", New TypeDescription("String"));
	Tree.Columns.Add("Class", New TypeDescription("Number", , New NumberQualifiers(10, 0, AllowedSign.Nonnegative)));
	Tree.Columns.Add("Picture", New TypeDescription("Picture"));
	
	AddTreeRootString(Tree, "Constant", NStr("en = 'Constants'"), 1, PictureLib.Constant);
	AddTreeRootString(Tree, "Catalog", NStr("en = 'Catalogs'"), 2, PictureLib.Catalog);
	AddTreeRootString(Tree, "Document", NStr("en = 'Documents'"), 3, PictureLib.Document);
	AddTreeRootString(Tree, "DocumentJournal", NStr("en = 'Document journals'"), 4, PictureLib.DocumentJournal);
	AddTreeRootString(Tree, "Enum", NStr("en = 'Enum'"), 5, PictureLib.Enum);
	AddTreeRootString(Tree, "ChartOfCharacteristicTypes", NStr("en = 'Charts of characteristics types'"), 6, PictureLib.ChartOfCharacteristicTypes);
	AddTreeRootString(Tree, "ChartOfAccounts", NStr("en = 'Charts of accounts'"), 7, PictureLib.ChartOfAccounts);
	AddTreeRootString(Tree, "ChartOfCalculationTypes", NStr("en = 'Charts of calculation types'"), 8, PictureLib.ChartOfCalculationTypes);
	AddTreeRootString(Tree, "InformationRegister", NStr("en = 'Information registers'"), 9, PictureLib.InformationRegister);
	AddTreeRootString(Tree, "AccumulationRegister", NStr("en = 'Accumulation registers'"), 10, PictureLib.AccumulationRegister);
	AddTreeRootString(Tree, "AccountingRegister", NStr("en = 'Accounting registers'"), 11, PictureLib.AccountingRegister);
	AddTreeRootString(Tree, "CalculationRegister", NStr("en = 'Calculation registers'"), 12, PictureLib.CalculationRegister);
	AddTreeRootString(Tree, "BusinessProcess", NStr("en = 'Business-processes'"), 13, PictureLib.BusinessProcess);
	AddTreeRootString(Tree, "Task", NStr("en = 'Tasks'"), 14, PictureLib.Task);
	AddTreeRootString(Tree, "ExchangePlan", NStr("en = 'Exchange plans'"), 15, PictureLib.ExchangePlan);
	
	For Each Dependence IN Parameters.ObjectDependencies Do
		AddTreeSubstring(Tree, Metadata.FindByFullName(Dependence));
	EndDo;
	
	Tree.Columns.Delete(Tree.Columns["DescriptionFull"]);
	Tree.Columns.Delete(Tree.Columns["Class"]);
	
	RowsToDelete = New Array();
	For Each TreeRow IN Tree.Rows Do
		If TreeRow.Rows.Count() = 0 Then
			RowsToDelete.Add(TreeRow);
		EndIf;
	EndDo;
	For Each RemovedRow IN RowsToDelete Do
		Tree.Rows.Delete(RemovedRow);
	EndDo;
	
	ValueToFormAttribute(Tree, "MetadataObjects");
	
EndProcedure

&AtServer
Procedure AddTreeRootString(Tree,Val DescriptionFull, Val Presentation, Val Class, Val Picture)
	
	NewRow = Tree.Rows.Add();
	NewRow.DescriptionFull = DescriptionFull;
	NewRow.Presentation = Presentation;
	NewRow.Class = Class;
	NewRow.Picture = Picture;
	
EndProcedure

Procedure AddTreeSubstring(Tree, Val MetadataObject)
	
	DescriptionFull = MetadataObject.FullName();
	
	NameStructure = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DescriptionFull, ".");
	ClassObject = NameStructure[0];
	
	RowOwner = Undefined;
	For Each TreeRow IN Tree.Rows Do
		If TreeRow.DescriptionFull = ClassObject Then
			RowOwner = TreeRow;
			Break;
		EndIf;
	EndDo;
	
	If RowOwner = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Unknown metadata object: %1'"), DescriptionFull);
	EndIf;
	
	NewRow = RowOwner.Rows.Add();
	
	NewRow.Presentation = MetadataObject.Presentation();
	NewRow.Class = RowOwner.Class;
	NewRow.Picture = RowOwner.Picture;
	
EndProcedure
