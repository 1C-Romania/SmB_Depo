////////////////////////////////////////////////////////////////////////////////
// Subsystem "Electronic documents".
// Server procedures and functions of common use:
// - for work with data tree;
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// Generates data tree for filling with applied solution.
//
// Parameters:
//  TemplateName - String - name of template based on which the tree is formed
//
// Returns:
//  ValuesTree.
//
Function DocumentTree(TemplateName) Export
	
	Template = DataProcessors.ElectronicDocuments.GetTemplate(TemplateName);
	TableHeight = Template.TableHeight;
	TableWidth = Template.TableWidth;
	ValueTable = New ValueTable;
	
	For ColumnNumber = 1 To TableWidth Do
		HeaderArea = Template.Area(1,ColumnNumber);
		ColumnName = HeaderArea.Text;
		ValueTable.Columns.Add(ColumnName);
	EndDo;
	
	For LineNumber = 2 To TableHeight Do
		NewRow = ValueTable.Add();
		For ColumnNumber = 0 To TableWidth-1 Do
			NewRow.Set(ColumnNumber, Template.Area(LineNumber, ColumnNumber + 1).Text);
		EndDo
	EndDo;
	ValueTable.Columns.Add("FullPath");
	ValueTable.Columns.Move("Value",   -6);
	ValueTable.Columns.Move("FullPath", -TableWidth);
	NumberOfLevels = 0;
	
	ValueTree = New ValueTree;
	For Each Column IN ValueTable.Columns Do
		ValueTree.Columns.Add(Column.Name);
		If Find(Column.Name, "Level") > 0 Then
			LevelNumber = Number(Mid(Column.Name, 6, 2));
			If LevelNumber > NumberOfLevels Then
				NumberOfLevels = LevelNumber;
			EndIf;
		EndIf;
	EndDo;
	
	FullPath = "";
	RecursivelyFillTreeRows(ValueTree, 1, NumberOfLevels, FullPath, ValueTable, 0);
	
	Return ValueTree;
	
EndFunction

// Saves a value in data tree
//
// Parameters:
//  Tree - ValueTree - data tree in which data
//  Attribute shall be saved - String - contains full
//  path to attribute Value - any type - saved
//  value TreeRootItem - String - It is required to use if in the
//    table complex data type (group, choice) shall be filled. For example: "Goods.LineNumber.Customer", Customer -
//    is a complex type of data, Then TreeRootItem = "Goods.LineNumber".
//
Procedure FillTreeAttributeValue(Tree, Attribute, Value, TreeRootItem = "") Export
	
	TreeRow = Tree.Rows.Find(Attribute, "FullPath", True);
	TreeRow.Value = Value;
	
	AttributeArray = CommonUseClientServer.SortStringByPointsAndSlashes(Attribute);
	If AttributeArray.Count() = 1 Then
		Return;
	EndIf;
	Path = "";
	For Each Item IN AttributeArray Do
		Path = ?(ValueIsFilled(Path), Path + "." + Item, Item);
		If Find(TreeRootItem, Path) > 0 Then
			Continue;
		EndIf;
		TreeRow = Tree.Rows.Find(Path, "FullPath", True);
		If TreeRow.SignOf = "Group" Then
			TreeRow.Value = True;
		ElsIf TreeRow.SignOf = "Choice" Then
			CurIndex = AttributeArray.Find(Item);
			TreeRow.Value = AttributeArray[CurIndex+1];
		EndIf;
	EndDo;
	
EndProcedure

// Writes data from values table to values tree
//
// Parameters:
//  Tree - ValueTree - data tree in which data
//  DataTable shall be saved - valuesTable - recorded
//  data TablesName in the tree - String - table name in the tree
//
Procedure ImportingTableToTree(Tree, DataTable, NameTables) Export
	
	TableRow = Tree.Rows.Find(NameTables, "FullPath", True);
	LineNumber = 0;
	For Each DataRow IN DataTable Do
		LineNumber = LineNumber + 1;
		If LineNumber = 1 Then
			CurRow = TableRow.Rows[0];
		Else
			FirstRow = TableRow.Rows[0];
			CurRow = TableRow.Rows.Add();
			FillPropertyValues(CurRow, FirstRow);
			CopyTreeRowsRecursively(CurRow, FirstRow);
		EndIf;
		CurRow.Value = LineNumber;
		For Each Column IN DataTable.Columns Do
			If Column.Name = "AdditionalInformationDigitallySigned" OR Column.Name = "AdditionalInformationIsNotDigitallySigned" Then
				
				RowOptionalData = CurRow.Rows.Find(CurRow.FullPath + "." + Column.Name, "FullPath");
				AdditDataStructure = DataRow[Column.Name];
				
				If ValueIsFilled(AdditDataStructure) Then
					AddAddDataInTree(
							RowOptionalData,
							AdditDataStructure,
							?(Column.Name = "AdditionalInformationDigitallySigned", True, False));
				EndIf;
				
				Continue;
			EndIf;
			FullPath = NameTables + ?(Column.Name = "LineNumber", ".", ".LineNumber.") + Column.Name;
			AttributeString = CurRow.Rows.Find(FullPath, "FullPath");
			If AttributeString <> Undefined Then
				If AttributeString.SignOf = "Table" AND Not DataRow[Column.Name] = Undefined Then
					ImportingTableToTree(CurRow, DataRow[Column.Name], FullPath);
				Else
					AttributeString.Value = DataRow[Column.Name];
				EndIf
			EndIf;
		EndDo
		
	EndDo;
	TableRow.Value = DataTable.Count();
	
EndProcedure

// Adds a string to the table from properties collection
//
// Parameters:
//  Tree - ValueTree - data tree in which data
//  Collection shall be saved - Structure, Selection, Values table row - collection for
//  saving in tree TableName - String - table name in the tree
//
Procedure AddRecordToTreeTable(Tree, Collection, NameTables) Export
	
	TableHeader = Tree.Rows.Find(NameTables, "FullPath", True);
	TableHeader.Value = ?(ValueIsFilled(TableHeader.Value), TableHeader.Value + 1, 1);
	
	ColumnStructure = ColumnStructureTableTree(Tree, NameTables);
	FillPropertyValues(ColumnStructure, Collection);
	FirstTreeRow = Tree.Rows.Find(NameTables + ".LineNumber", "FullPath", True);
	
	If IsBlankString(FirstTreeRow.Value) Then
		NewRow = FirstTreeRow;
		LineNumber = 1;
	Else
		Table = Tree.Rows.Find(NameTables, "FullPath", True);
		LineNumber = Table.Rows.Count() + 1;
		NewRow = Table.Rows.Add();
		NewRow.FullPath = NameTables + ".LineNumber";
		CopyTreeRowsRecursively(NewRow, FirstTreeRow);
	EndIf;
	
	FillPropertyValues(NewRow, FirstTreeRow);
	NewRow.Value = LineNumber;
	
	For Each Item IN NewRow.Rows Do
		
		If ColumnName(Item.FullPath) = "AddData" Then
			If ColumnStructure.Property("AdditionalInformationDigitallySigned") Then
				AddAddDataInTree(Item, ColumnStructure.AdditionalInformationDigitallySigned, True);
			EndIf;
			If ColumnStructure.Property("AdditionalInformationIsNotDigitallySigned") Then
				AddAddDataInTree(Item, ColumnStructure.AdditionalInformationIsNotDigitallySigned);
			EndIf;
			Continue;
		EndIf;
		
		Item.Value = ColumnStructure[ColumnName(Item.FullPath)];
		
	EndDo
	
EndProcedure

// Returns values table with data of values tree
//
// Parameters:
//  DataTree - ValueTree - tree
//  with data TableName - String - name of the table in the tree if it is required to get tabular section data
//
// Returns:
//  ValueTable - contains tree data
//
Function DataTree(DataTree, NameTables = Undefined) Export
	
	If ValueIsFilled(NameTables) Then
		Return DataTableTree(DataTree, NameTables);
	Else
		Return HeaderDataTree(DataTree);
	EndIf;
	
EndFunction

// Returns a string of values tree for completion in the applied solution
//
// Parameters:
//  DataTree - ValueTree - tree
//  with data FieldName - String - name of a field in the tree that
//  contains full path to attribute FindRecursively - Boolean, True - if recursive search is required
//
// Returns:
//  Values table row - contains string tree
//
Function TreeRow(DataTree, FieldsName, FindRecursively = False) Export
	
	ReturnString = DataTree.Rows.Find(FieldsName, "FullPath", FindRecursively);
	If ReturnString.SignOf = "Group" Then
		ReturnString.Value = True;
	EndIf;
	Return ReturnString;

EndFunction

// IN the procedure data is added from DataSrtucture to ValuesTree.
//
// Parameters:
//  DataTree - ValuesTree or a row of values tree which contains data.
//  DataStructure - Structure, data to be placed to the tree.
//  LegallyMeaningful - Boolean - if True - then current data shall be put in default ED if possible.
//
Procedure AddAddDataInTree(TreeRow, AdditDataStructure, LegallyMeaningful = False) Export
	
	If AdditDataStructure.Count() = 0 Then
		Return;
	EndIf;
	
	If TreeRow.Rows.Parent = Undefined Then
		ValueTreeRow = TreeRow(TreeRow, "AddData");
		If LegallyMeaningful Then
			StringAdditionalInformation = ValueTreeRow.Rows.Find("AdditData.Signed", "FullPath");
		Else
			StringAdditionalInformation = ValueTreeRow.Rows.Find("AdditData.Unsigned", "FullPath");
		EndIf;
	ElsIf ColumnName(TreeRow.FullPath) = "AdditionalInformationDigitallySigned"
			OR ColumnName(TreeRow.FullPath) = "AdditionalInformationIsNotDigitallySigned" Then
		StringAdditionalInformation = TreeRow;
	Else
		TreeRow.Value = True;
		StringAdditionalInformation = TreeRow.Rows[?(LegallyMeaningful, 0 ,1)];
	EndIf;
	StringAdditionalInformation.Value = True;
	
	For Each Item IN AdditDataStructure Do
		NewRow = StringAdditionalInformation.Rows.Find(StringAdditionalInformation.FullPath + "." + Item.Key, "FullPath");
		If NewRow = Undefined Then
			NewRow = StringAdditionalInformation.Rows.Add();
			NewRow.FullPath = StringAdditionalInformation.FullPath + "." + Item.Key;
			LevelNumber = StrOccurrenceCount(NewRow.FullPath, ".") + 1;
			NewRow["Level" + LevelNumber] = ColumnName(NewRow.FullPath);
		EndIf;
		NewRow.Value = Item.Value;
	EndDo;
	
EndProcedure

// Returns attribute name from full path
//
// Parameters:
//  FullPath - String - Full path to the attribute in the tree
//
// Returns:
//  String - Attribute name
//
Function ColumnName(FullPath) Export
	
	RowArray = CommonUseClientServer.SortStringByPointsAndSlashes(FullPath);
	Return RowArray[RowArray.Count()-1];
	
EndFunction

// Checks the existence of an attribute in the tree by specified path.
Function AttributeExistsInTree(DataTree, FullPath) Export
	
	Exists = False;
	FoundString = DataTree.Rows.Find(FullPath, "FullPath", True);
	If FoundString <> Undefined Then
		Exists = True;
	EndIf;
	
	Return Exists;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

Function HeaderDataTree(DataTree)
	
	ReturnTable = New ValueTable;
	For Each Column IN DataTree.Columns Do
		ReturnTable.Columns.Add(Column.Name);
	EndDo;
	
	FillTableRecursively(ReturnTable, DataTree.Rows);
	
	Return ReturnTable;
	
EndFunction

Function DataTableTree(DataTree, NameTables)
	
	ReturnTable = New ValueTable;
	TableRow = DataTree.Rows.Find(NameTables, "FullPath");
	LineNumber = TableRow.Rows[0];
	For Each String IN LineNumber.Rows Do
		ReturnTable.Columns.Add(ColumnName(String.FullPath));
	EndDo;
	
	For Each String IN TableRow.Rows Do
		NewRow = ReturnTable.Add();
		For Each AttributeString IN String.Rows Do
			NewRow[ColumnName(AttributeString.FullPath)] = AttributeString.Value;
		EndDo;
	EndDo;
		
	Return ReturnTable;
	
EndFunction

Procedure FillTableRecursively(ValueTable, TreeRows, NameTables = Undefined)
	
	For Each String IN TreeRows Do
		If Not String.SignOf = "Table" Then
			NewRow = ValueTable.Add();
			FillPropertyValues(NewRow, String);
			If String.Rows.Count()>0 Then
				FillTableRecursively(ValueTable, String.Rows);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CopyTreeRowsRecursively(RecipientRow, RowSource)
	
	For Each Attribute IN RowSource.Rows Do
		If ColumnName(Attribute.FullPath) = "LineNumber" AND TypeOf(Attribute.Value) = Type("Number")
				AND Attribute.Value > 1 Then
			Break;
		EndIf;
		NewRow = RecipientRow.Rows.Add();
		FillPropertyValues(NewRow, Attribute);
		NewRow.Value = "";
		If Attribute.Rows.Count() > 0 Then
			CopyTreeRowsRecursively(NewRow, Attribute);
		EndIf;
	EndDo;

EndProcedure

Function ColumnStructureTableTree(Tree, NameTables)
	
	ReturnStructure = New Structure;
	
	TreeRow = Tree.Rows.Find(NameTables + ".LineNumber", "FullPath", True);
	For Each Substring IN TreeRow.Rows Do
		ColumnName = ColumnName(Substring.FullPath);
		If ColumnName = "AddData" Then
			ReturnStructure.Insert("AdditionalInformationDigitallySigned");
			ReturnStructure.Insert("AdditionalInformationIsNotDigitallySigned");
		Else
			ReturnStructure.Insert(ColumnName);
		EndIf;
	EndDo;
	
	Return ReturnStructure;
	
EndFunction

Procedure RecursivelyFillTreeRows(ValueTree, Val LevelNumber, NumberOfLevels, Val FullPathInTree, VT, LineNumberOfVT)
	
	LocFullPath = FullPathInTree;
	StringCurLevel = Undefined;
	While LineNumberOfVT < VT.Count() Do
		VTRow = VT[LineNumberOfVT];
		For Ct = LevelNumber To NumberOfLevels Do
			CurLevelId = "Level" + Ct;
			If VT.Columns.Find(CurLevelId) <> Undefined AND ValueIsFilled(VTRow[CurLevelId]) Then
				If LevelNumber < Ct Then
					RecursivelyFillTreeRows(StringCurLevel, Ct, NumberOfLevels, LocFullPath, VT, LineNumberOfVT);
				ElsIf LevelNumber = Ct Then
					StringCurLevel = ValueTree.Rows.Add();
					FillPropertyValues(StringCurLevel, VTRow);
					LocFullPath = ?(FullPathInTree = "", "", FullPathInTree + ".") + StringCurLevel["Level" + Ct];
					StringCurLevel.FullPath = LocFullPath;
				EndIf;
				LineNumberOfVT = LineNumberOfVT + 1;
				Break;
			EndIf;
			If Ct >= NumberOfLevels Then
				LineNumberOfVT = LineNumberOfVT - 1;
				Return;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure
