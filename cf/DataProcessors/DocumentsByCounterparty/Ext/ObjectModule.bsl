#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure generates the queries table.
//
Procedure FillQueryTable(RequestsTable, AdditDocuments, AddHeaderFields, ConsiderTSInAdditDocuments = False,ActualOnly = False, NameSelectionCriterias = "DocumentsByCounterparty") Export

	DocumentsTree = New ValueTree;
	DocumentsTree.Columns.Add("Document");
	DocumentsTree.Columns.Add("DataStructure");
	DocumentsTree.Columns.Add("TabularSection");
	DocumentsTree.Columns.Add("ConditionText");

	For Each ContentItem IN Metadata.FilterCriteria[NameSelectionCriterias].Content Do

		DataStructure = GetDataStructure(ContentItem.FullName());

		If Not AccessRight("Read", DataStructure.Metadata) Then
			Continue;
		EndIf;

		RootDocument = DocumentsTree.Rows.Find(DataStructure.Metadata, "Document", False);
		If RootDocument = Undefined Then

			RootDocument = DocumentsTree.Rows.Add();
			RootDocument.Document = DataStructure.Metadata;

		EndIf;

		RowTSHeader = RootDocument.Rows.Find(DataStructure.TabulSectName, "TabularSection", False);
		If RowTSHeader = Undefined Then

			RowTSHeader = RootDocument.Rows.Add();
			RowTSHeader.TabularSection = DataStructure.TabulSectName;

		EndIf;

		DataRow = RowTSHeader.Rows.Add();
		DataRow.DataStructure = DataStructure;

	EndDo;

	HeaderPatternCondition = " %PathToAttributeTable%.%FieldHeaderParameter% = &Parameter ";
	QueryPattern = 
	"SELECT
	|	HeaderTable.Ref              AS Document,
	|	//%AdditFieldsRow%
	|	HeaderTable.Number               AS Number,
	|	HeaderTable.Date                AS Date,
	|	VALUETYPE(HeaderTable.Ref) AS DocumentType,
	|	CASE
	|		WHEN HeaderTable.Posted THEN
	|			1
	|		WHEN HeaderTable.DeletionMark THEN
	|			2
	|		ELSE 0
	|	END                        AS ImageID
	|FROM
	|	Document.%HeaderTableName% AS HeaderTable
	|WHERE
	| (%ConditionText%)
	|";
	PatternConditionForTS = " TableOfStrings.%FieldTSParameter% = &Parameter ";
	TSConditionPattern    = 
	" 1 In
	|	(SELECT TOP 1
	|			1
	|	FROM
	|		Document.%TableNameOfTS% AS TableOfStrings
	|	WHERE
	|		TableOfStrings.Ref = HeaderTable.Ref
	|		AND ( %ConditionOnTSRows% )
	|	)";

	For Each RootRow IN DocumentsTree.Rows Do

		ConditionsTextByDocument = "";
		// Cycle by the attributes and tabular sections of the same document
		For Each RowTSAttribute IN RootRow.Rows Do

			ConditionText = "";
			// Condition on the field in TS.
			If Not IsBlankString(RowTSAttribute.TabularSection) Then

				TempText = "";
				// Cycle by tabular sections
				For Each TSRow IN RowTSAttribute.Rows Do

					TempText = TempText + ?(IsBlankString(TempText),"", " OR ")
						+ StrReplace(PatternConditionForTS, "%FieldTSParameter%", TSRow.DataStructure.AttributeName);

				EndDo;

				ConditionText = StrReplace(TSConditionPattern, "%TableNameOfTS%", RootRow.Document.Name + "." + RowTSAttribute.TabularSection);
				ConditionText = StrReplace(ConditionText, "%ConditionOnTSRows%", TempText);

			Else // Condition on the header

				// Cycle by attributes
				For Each TSRow IN RowTSAttribute.Rows Do

					ConditionText = ConditionText + ?(IsBlankString(ConditionText),"", " OR ")
						+ StrReplace(HeaderPatternCondition, "%FieldHeaderParameter%", TSRow.DataStructure.AttributeName);

				EndDo; 					

			EndIf;                                                                                        
			
			If Not IsBlankString(ConditionText) Then                          

				AddTextToString(ConditionsTextByDocument, ConditionText, " OR ");

			EndIf;
		EndDo;

		If Not IsBlankString(ConditionsTextByDocument) Then

			QueryText = StrReplace(QueryPattern, "%HeaderTableName%", RootRow.Document.Name);
			QueryText = StrReplace(QueryText, "%ConditionText%", ConditionsTextByDocument);
			QueryText = StrReplace(QueryText, "%PathToAttributeTable%", "HeaderTable");

			AddAdditionalHeaderFields(QueryText,RootRow.Document, AddHeaderFields);
			
			If RootRow.Document.Name = "SubcontractorReport" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentAmount,", "REFPRESENTATION(HeaderTable.Total) AS DocumentAmount,");	
			EndIf;
			
			If RootRow.Document.Name = "CashReceipt" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "PaymentReceipt" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "CashPayment" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "PaymentExpense" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "PaymentOrder" Then
				QueryText = StrReplace(QueryText, "NULL  AS DocumentCurrency,", "REFPRESENTATION(HeaderTable.BankAccount.CashCurrency) AS DocumentCurrency,");	
			EndIf;
			
			If RootRow.Document.Name = "EnterOpeningBalance" Then
				QueryText = StrReplace(QueryText, "NULL  AS OperationKind,", "REFPRESENTATION(HeaderTable.AccountingSection) AS OperationKind,");	
			EndIf;
			
			AddQueryTable(RequestsTable, RootRow.Document, QueryText);
			
			RootRow.ConditionText = ConditionsTextByDocument;

		EndIf;
	EndDo;

	// Documents are added in the query that are not included in the criterion, 
	// but have a reference to the document that is included in the criterion by the header attribute.

	ConditionPatternOfTSRow = 
	"1 In
	|	(SELECT
	|		1
	|	FROM
	|		Document.%DocumentName% AS TabularSection
	|	WHERE
	|		TabularSection.Ref = HeaderTable.Ref
	|		AND (%ConditionText%)
	|)";
	ArrayOfConditions      = New Array;
	FieldMap  = New Map;

	For Each Document IN AdditDocuments Do
		If Not AccessRight("Read", Document) Then
			Continue;
		EndIf;

		ArrayOfConditions.Clear();
		FieldMap.Clear();

		For Each Attribute IN Document.Attributes Do
			For Each TreeRow IN DocumentsTree.Rows Do

				// Check that the basis document contains the required reference only in the header.
				If Not AttributeContainsType(Attribute, "DocumentRef." + TreeRow.Document.Name)
				 Or Not AttributeInHeaderOnly(TreeRow) Then
					Continue;
				EndIf;

				StructuresArray = FieldMap.Get(Attribute);
				If StructuresArray = Undefined Then

					StructuresArray = New Array;
					FieldMap.Insert(Attribute, StructuresArray);

				EndIf;
				StructuresArray.Add(New Structure("Document, ConditionText",
												TreeRow.Document,
												TreeRow.ConditionText));
			EndDo;
		EndDo;

		For Each KeyAndValue IN FieldMap Do
			For Each ItemStructure IN KeyAndValue.Value Do

				If CompoundAttribute(KeyAndValue.Key) Then
					PathToAttributeTable = "CAST(HeaderTable." + KeyAndValue.Key.Name +" AS Document." + ItemStructure.Document.Name + ")";
				Else
					PathToAttributeTable = "HeaderTable." + KeyAndValue.Key.Name;
				EndIf;

				TempText = ItemStructure.ConditionText;
				TempText = StrReplace(TempText, "%PathToAttributeTable%", PathToAttributeTable);
				TempText = StrReplace(TempText, "%FieldParameter%", KeyAndValue.Key.Name);
				ArrayOfConditions.Add(TempText);

			EndDo;
		EndDo;

		// By tabular sections
		If ConsiderTSInAdditDocuments Then
			For Each TabSection IN Document.TabularSections Do

				FieldMap.Clear();
				For Each Attribute IN TabSection.Attributes Do
					For Each TreeRow IN DocumentsTree.Rows Do

						If Not AttributeContainsType(Attribute, "DocumentRef." + TreeRow.Document.Name)
						 Or Not AttributeInHeaderOnly(TreeRow) Then
							Continue;
						EndIf;

						StructuresArray = FieldMap.Get(Attribute);
						If StructuresArray = Undefined Then

							StructuresArray = New Array;
							FieldMap.Insert(Attribute, StructuresArray);

						EndIf;
						StructuresArray.Add(New Structure("Document, ConditionText",
														TreeRow.Document,
														TreeRow.ConditionText));
					EndDo;
				EndDo;

				// Building the condition by tabular section.
				If FieldMap.Count() > 0 Then
					TempText = "";
					For Each KeyAndValue IN FieldMap Do
						For Each CurStructure IN KeyAndValue.Value Do

							If CompoundAttribute(KeyAndValue.Key) Then
								PathToTable = "CAST(TabularSection." + KeyAndValue.Key.Name +" AS Document." + CurStructure.Document.Name + ")";
							Else
								PathToTable = "TabularSection." + KeyAndValue.Key.Name;
							EndIf;

							AddTextToString(TempText,
									StrReplace(CurStructure.ConditionText, "%PathToAttributeTable%", PathToTable),
									" OR ");
						EndDo;
					EndDo;

					TempText = StrReplace(ConditionPatternOfTSRow, "%ConditionText%", TempText);
					TempText = StrReplace(TempText, "%DocumentName%", Document.Name + "." + TabSection.Name);

					ArrayOfConditions.Add(TempText);

				EndIf;
			EndDo;
		EndIf;

		If ArrayOfConditions.Count() > 0 Then

			QueryText = StrReplace(QueryPattern, "%HeaderTableName%", Document.Name);
			QueryText = StrReplace(QueryText, "%ConditionText%", CompileStringFromArray(ArrayOfConditions, " OR "));

			AddAdditionalHeaderFields(QueryText, Document, AddHeaderFields);
			AddQueryTable(RequestsTable, Document, QueryText);

		EndIf;

	EndDo;

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure AddTextToString(String, Text, Delimiter = " Or ")

	String = String + ?(IsBlankString(String), "", Delimiter) + Text;

EndProcedure

Function CompileStringFromArray(RowArray, Delimiter = " Or ")

	Result = "";
	For Each Item IN RowArray Do

		AddTextToString(Result, Item, Delimiter);

	EndDo;

	Return Result;

EndFunction

Function GetDataStructure(DataPath)
	
	Structure = New Structure;
	
	MapOfNames = New Array();
	MapOfNames.Add("ObjectType");
	MapOfNames.Add("ObjectKind");
	MapOfNames.Add("DataPath");
	MapOfNames.Add("TabulSectName");
	MapOfNames.Add("AttributeName");
	
	For index = 1 to 3 Do
		
		Point = Find(DataPath, ".");
		CurrentValue = Left(DataPath, Point-1);
		Structure.Insert(MapOfNames[index-1], CurrentValue);
		DataPath = Mid(DataPath, Point+1);
		
	EndDo;
	
	DataPath = StrReplace(DataPath, "Attribute.", "");
	
	If Structure.DataPath = "TabularSection" Then
		
		For index = 4 to 5  Do 
			
			Point = Find(DataPath, ".");
			If Point = 0 Then
				CurrentValue = DataPath;
			Else
				CurrentValue = Left(DataPath, Point-1);
			EndIf;
			
			Structure.Insert(MapOfNames[index-1], CurrentValue);
			DataPath = Mid(DataPath,  Point+1);
			
		EndDo;
		
	Else
		
		Structure.Insert(MapOfNames[3], "");
		Structure.Insert(MapOfNames[4], DataPath);
		
	EndIf;
	
	If Structure.ObjectType = "Document" Then
		Structure.Insert("Metadata", Metadata.Documents[Structure.ObjectKind]);
	Else
		Structure.Insert("Metadata", Metadata.Catalogs[Structure.ObjectKind]);
	EndIf;

	
	Return Structure;
	
EndFunction

Procedure AddQueryTable(RequestsTable, DocumentMetadata, QueryText)

	TabRow = RequestsTable.Add();
	TabRow.DocumentName     = DocumentMetadata.Name;
	TabRow.DocumentSynonym = DocumentMetadata.Synonym;
	TabRow.Use     = True;
	TabRow.QueryText     = QueryText;

EndProcedure

Procedure AddAdditionalHeaderFields(QueryText, DocumentMetadata, AddHeaderFields)

	FieldPattern  = "%FieldName% AS %FieldPseudonym%,";
	FieldsRow = "";

	For Each FieldName IN AddHeaderFields Do

		If DocumentMetadata.Attributes.Find(FieldName) <> Undefined Then

			Text = StrReplace(FieldPattern, "%FieldName%", "REFPRESENTATION(HeaderTable." + FieldName +" ) ");

		ElsIf FieldName = "Division"
			AND DocumentMetadata.Attributes.Find("SalesStructuralUnit") <> Undefined Then

			Text = StrReplace(FieldPattern, "%FieldName%", "REFPRESENTATION(HeaderTable.SalesStructuralUnit) ");
            Text = StrReplace(Text, "%FieldPseudonym%", "Division");

		ElsIf FieldName = "Division"
			AND DocumentMetadata.Attributes.Find("StructuralUnit") <> Undefined Then

			Text = StrReplace(FieldPattern, "%FieldName%", "REFPRESENTATION(HeaderTable.StructuralUnit) ");
            Text = StrReplace(Text, "%FieldPseudonym%", "Division");

		Else

			Text = StrReplace(FieldPattern, "%FieldName%", " NULL ");

		EndIf;

		FieldsRow = FieldsRow + ?(IsBlankString(FieldsRow), "", Chars.LF)
				+ StrReplace(Text, "%FieldPseudonym%", FieldName);

	EndDo;

	QueryText = StrReplace(QueryText, "//%AdditFieldsRow%", FieldsRow);

EndProcedure

Function CompoundAttribute(AttributeMetadata)

	Return AttributeMetadata.Type.Types().Count() > 1;

EndFunction

Function AttributeContainsType(AttributeMetadata, TypeName)

	Return AttributeMetadata.Type.ContainsType(Type(TypeName));

EndFunction

Function AttributeInHeaderOnly(TreeRow)

	Return TreeRow.Rows.Count() 
						= TreeRow.Rows.FindRows(New Structure("TabularSection", ""), False).Count();
						
EndFunction

#EndRegion

#EndIf