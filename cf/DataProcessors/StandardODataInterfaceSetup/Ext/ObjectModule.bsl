#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalState

Var ObjectsTree;
Var AddDependencies;
Var DeletionDependencies;
Var StandardInterfaceContent;

#EndRegion

#Region ServiceProgramInterface

Function InitializeDataToSetupStandardODataInterface() Export
	
	// Fill tree root strings (by metadata objects collections)
	AddTreeRootString("Constant", NStr("en='Constants';ru='Константы'"), 1, PictureLib.Constant);
	AddTreeRootString("Catalog", NStr("en='Catalogs';ru='Справочники'"), 2, PictureLib.Catalog);
	AddTreeRootString("Document", NStr("en='Documents';ru='Документы'"), 3, PictureLib.Document);
	AddTreeRootString("DocumentJournal", NStr("en='Document journals';ru='Журналы документов'"), 4, PictureLib.DocumentJournal);
	AddTreeRootString("Enum", NStr("en='Enum';ru='Перечисление'"), 5, PictureLib.Enum);
	AddTreeRootString("ChartOfCharacteristicTypes", NStr("en='Charts of characteristics types';ru='Планы видов характеристик'"), 6, PictureLib.ChartOfCharacteristicTypes);
	AddTreeRootString("ChartOfAccounts", NStr("en='Charts of accounts';ru='Планы счетов'"), 7, PictureLib.ChartOfAccounts);
	AddTreeRootString("ChartOfCalculationTypes", NStr("en='Charts of calculation types';ru='Планы видов расчета'"), 8, PictureLib.ChartOfCalculationTypes);
	AddTreeRootString("InformationRegister", NStr("en='Information registers';ru='Регистры сведений'"), 9, PictureLib.InformationRegister);
	AddTreeRootString("AccumulationRegister", NStr("en='Accumulation registers';ru='Регистры накопления'"), 10, PictureLib.AccumulationRegister);
	AddTreeRootString("AccountingRegister", NStr("en='Accounting registers';ru='Регистры бухгалтерии'"), 11, PictureLib.AccountingRegister);
	AddTreeRootString("CalculationRegister", NStr("en='Calculation registers';ru='Регистры расчета'"), 12, PictureLib.CalculationRegister);
	AddTreeRootString("BusinessProcess", NStr("en='Business-processes';ru='Деловые процессы'"), 13, PictureLib.BusinessProcess);
	AddTreeRootString("Task", NStr("en='Tasks';ru='Задания'"), 14, PictureLib.Task);
	AddTreeRootString("ExchangePlan", NStr("en='Exchange plans';ru='Планы обмена'"), 15, PictureLib.ExchangePlan);
	
	// Read current content of standard OData interface
	SystemContent = WorkInSafeMode.EvalInSafeMode("GetStandardODataInterfaceContent()");
	StandardInterfaceContent = New Array();
	For Each Item IN SystemContent Do
		StandardInterfaceContent.Add(Item.FullName());
	EndDo;
	
	// Read data model provided for standard OData interface
	Model = DataProcessors.StandardODataInterfaceSetup.DataModelProvidedForStandardODataInterface();
	
	// Fill tree substrings (by metadata objects inlcuded in the model)
	For Each ModelItem IN Model Do
		
		DescriptionFull = ModelItem.DescriptionFull;
		ThisIsReadOnlyObject = Not ModelItem.Update;
		ThisIsObjectIncludedInContent = (StandardInterfaceContent.Find(ModelItem.DescriptionFull) <> Undefined);
		Dependencies = ModelItem.Dependencies;
		
		If CommonUseSTL.MetadataObjectAvailableByFunctionalOptions(DescriptionFull) Then
			
			AddTreeSubstring(DescriptionFull, ThisIsReadOnlyObject,
				ThisIsObjectIncludedInContent, Dependencies);
			
		EndIf;
		
	EndDo;
	
	// Remove root strings (from metadata collections for which there are no objects to include in the content).
	RowsToDelete = New Array();
	For Each TreeRow IN ObjectsTree.Rows Do
		If TreeRow.Rows.Count() = 0 Then
			RowsToDelete.Add(TreeRow);
		EndIf;
	EndDo;
	For Each RemovedRow IN RowsToDelete Do
		ObjectsTree.Rows.Delete(RemovedRow);
	EndDo;
	
	// Sort substrings by metadata objects display
	For Each Substring IN ObjectsTree.Rows Do
		Substring.Rows.Sort("Presentation");
	EndDo;
	
	Result = New Structure();
	Result.Insert("ObjectsTree", ObjectsTree);
	Result.Insert("AddDependencies", AddDependencies);
	Result.Insert("DeletionDependencies", DeletionDependencies);
	
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddTreeSubstring(Val DescriptionFull, Val ReadOnly, Val Use, Val Dependencies)
	
	NameStructure = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(DescriptionFull, ".");
	ClassObject = NameStructure[0];
	
	RowOwner = Undefined;
	For Each TreeRow IN ObjectsTree.Rows Do
		If TreeRow.DescriptionFull = ClassObject Then
			RowOwner = TreeRow;
			Break;
		EndIf;
	EndDo;
	
	If RowOwner = Undefined Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Unknown metadata object: %1';ru='Неизвестный объект метаданных: %1'"), DescriptionFull);
	EndIf;
	
	NewRow = RowOwner.Rows.Add();
	
	NewRow.DescriptionFull = DescriptionFull;
	NewRow.Presentation = CommonUseSTL.MetadataObjectPresentation(DescriptionFull);
	NewRow.Class = RowOwner.Class;
	NewRow.Picture = RowOwner.Picture;
	NewRow.Use = StandardInterfaceContent.Find(DescriptionFull) <> Undefined;
	NewRow.subordinated = CommonUseSTL.ThisIsRecordSet(DescriptionFull) AND
		Not CommonUseSTL.IsIndependentRecordSet(DescriptionFull);
	NewRow.ReadOnly = ReadOnly;
	NewRow.Use = Use;
	
	For Each ObjectDependence IN Dependencies Do
		
		If CommonUseSTL.MetadataObjectAvailableByFunctionalOptions(ObjectDependence) Then
			
			// If you include object MetadataObject in the content, it is required to include object ObjectDependence as well.
			String = AddDependencies.Add();
			String.ObjectName = DescriptionFull;
			String.DependentObjectName = ObjectDependence;
			
			// If you exclude object ObjectDependence from the content, it is required to exclude object MetadataObject as well.
			String = DeletionDependencies.Add();
			String.ObjectName = ObjectDependence;
			String.DependentObjectName = DescriptionFull;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure AddTreeRootString(Val DescriptionFull, Val Presentation, Val Class, Val Picture)
	
	NewRow = ObjectsTree.Rows.Add();
	NewRow.DescriptionFull = DescriptionFull;
	NewRow.Presentation = Presentation;
	NewRow.Class = Class;
	NewRow.Picture = Picture;
	NewRow.subordinated = False;
	NewRow.ReadOnly = False;
	NewRow.Root = True;
	
EndProcedure

#EndRegion

#Region Initialization

ObjectsTree = New ValueTree();
ObjectsTree.Columns.Add("DescriptionFull", New TypeDescription("String"));
ObjectsTree.Columns.Add("Presentation", New TypeDescription("String"));
ObjectsTree.Columns.Add("Class", New TypeDescription("Number", , New NumberQualifiers(10, 0, AllowedSign.Nonnegative)));
ObjectsTree.Columns.Add("Picture", New TypeDescription("Picture"));
ObjectsTree.Columns.Add("Use", New TypeDescription("Boolean"));
ObjectsTree.Columns.Add("subordinated", New TypeDescription("Boolean"));
ObjectsTree.Columns.Add("ReadOnly", New TypeDescription("Boolean"));
ObjectsTree.Columns.Add("Root", New TypeDescription("Boolean"));

StandardInterfaceContent = New Array();

AddDependencies = New ValueTable();
AddDependencies.Columns.Add("ObjectName", New TypeDescription("String"));
AddDependencies.Columns.Add("DependentObjectName", New TypeDescription("String"));

DeletionDependencies = New ValueTable();
DeletionDependencies.Columns.Add("ObjectName", New TypeDescription("String"));
DeletionDependencies.Columns.Add("DependentObjectName", New TypeDescription("String"));

#EndRegion

#EndIf