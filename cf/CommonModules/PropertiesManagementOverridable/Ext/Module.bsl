////////////////////////////////////////////////////////////////////////////////
// Properties subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Fills object property sets. Usually required if there is more than one set.
//
// Parameters:
//  Object       - Reference to properties owner.
//                 Object of properties owner.
//                 FormDataStructure (by object type of properties owner).
//
//  ReferenceType    - Type - type of reference of properties owner.
//
//  PropertiesSets - ValuesTable with columns:
//                    Set - CatalogRef.AdditionalAttributesAndInformationSets.
//
//                    // Then, the form item properties of the FormGroup type, common group kind or page, which is formed if the number of sets is more than one disregarding the empty set that describes group properties of the remote attributes.
//                     
//                     
//                    
//                    // If value is Undefined then use default value.
//                    
//                    // For any managed form group.
//                    Height            - Number.
//                    Title             - String.
//                    ToolTip           - String.
//                    VerticalStretch   - Boolean.
//                    HorizontalStretch - Boolean.
//                    ReadOnly          - Boolean.
//                    TitleTextColor    - Color.
//                    Width             - Number.
//                    TitleFont         - Font.
//                    
//                    // For common group and page.
//                    Group             - FormSubelementsGrouping.
//                    
//                    // For common group.
//                    Representation    - UsualGroupRepresentation.
//                    ChildItemsWidth   - FormSubelementsWidth.
//                    
//                    // For page.
//                    Picture           - Picture.
//                    ShowTitle         - Boolean.
//
//  StandardProcessing - Boolean - initial value is True. Specifies whether receive core set or not, when PropertiesSets.Count() equals zero.
//                         
//
//  PurposeKey   - Undefined - (initial value) - specifies to calculate function key automatically and add to form property value.
//                      
//                      PurposeUseKey, to save form changes separately for different sets content.
//                      
//                      For example, for each type of products and services - their set structure.
//
//                    - String - (up to 32 letters) - use specified purpose key to add to the property value of the PurposeUseKey form.
//                      
//                      Blank string - do not change PurposeUseKey as
//                      It is specified on the form, and it already takes into account the differences in the sets content.
//
//                    Addition has the format as "PropertiesSetsKey<PurposeKey>" in order to
//                    <PurposeKey> can be updated without repeated addition.
//                    In automatic calculation the <PurposeKey> contains the ID hash of references to ordered property sets.
//                    
//
Procedure FillObjectPropertiesSets(Object, ReferenceType, PropertiesSets, StandardProcessing, PurposeKey) Export
	
	
	
EndProcedure

// Outdated. It will be deleted in the next edition of the SSL.
// 
// Now instead of specifying the attribute name containing the property owner kind, for example, ProductsAndServicesKind of the CatalogRef.ProductsAndServicesKinds which should have the attribute of the PropertySet type.
// 
// 
// CatalogRef.AdditionalDetailAndInformationSets you should feill proprty set for object CatalogRef.List in procedure FillOjectPropertiesSets as for few property sets.
// The difference is only that the set will be received internally from the owner kind object attribute which allows to use several different attributes with convenient names for different object kinds which have one object kind. 
// For example, Catalog.Projects is a property owner kind of Catalog.Errors and Catalog.Tasks for which the ErrorsPropertiesSet, TasksPropertiesSet attributes will be in the Projects catalog.
// 
//
Function GetObjectKindAttributeName(Ref) Export
	
	Return "";
	
EndFunction

#EndRegion


#Region ServiceInterfaceSB

// Copy necessary strings from formed value tree to another tree.
//
Procedure CopyStringValuesTree(RowsWhereTo, RowsFrom, Parent)
	
	For Each Str IN RowsFrom Do
		If Str.Property = Parent Then
			CopyStringValuesTree(RowsWhereTo, Str.Rows, Str.Property);
		Else
			NewRow = RowsWhereTo.Add();
			FillPropertyValues(NewRow, Str);
			CopyStringValuesTree(NewRow.Rows, Str.Rows, Str.Property);
		EndIf;
		
	EndDo;
	
EndProcedure // CopyStringValuesTree()

// Form property value tree to edit in object form.
//
Function GetTreeForEditPropertiesValues(PrListOfSets, propertiesTab, ForAddDetails)
	
	PrLstSelected = New ValueList;
	For Each Str IN propertiesTab Do
		If PrListOfSets.FindByValue(Str.Property) = Undefined Then
			PrLstSelected.Add(Str.Property);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AdditionalAttributesAndInformation.Ref AS Property,
	|	AdditionalAttributesAndInformation.ValueType AS PropertyValueType,
	//|	AdditionalAttributesAndInformation.IsFolder AS IsFolder,
	|	AdditionalAttributesAndInformation.FormatProperties AS FormatProperties,
	|	Properties.LineNumber AS LineNumber,
	|	CASE
	//|		WHEN AdditionalAttributesAndInformation.IsFolder
	//|			THEN 0
	|		WHEN Properties.Error
	|			THEN 1
	|		ELSE -1
	|	END AS PictureNumber
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS AdditionalAttributesAndInformation
	|		INNER JOIN (SELECT DISTINCT
	|			PropertiesSetsContent.Property AS Property,
	|			FALSE AS Error,
	|			PropertiesSetsContent.LineNumber AS LineNumber
	|		FROM
	|			Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS PropertiesSetsContent
	|		WHERE
	|			PropertiesSetsContent.Ref IN(&PrListOfSets)
	|			AND PropertiesSetsContent.Property.ThisIsAdditionalInformation = &ThisIsAdditionalInformation
	|		
	|		UNION
	|		
	|		SELECT
	|			AdditionalAttributesAndInformation.Ref,
	|			TRUE,
	|			PropertiesSetsContent.LineNumber
	|		FROM
	|			ChartOfCharacteristicTypes.AdditionalAttributesAndInformation AS AdditionalAttributesAndInformation
	|				LEFT JOIN Catalog.AdditionalAttributesAndInformationSets.AdditionalAttributes AS PropertiesSetsContent
	|				ON (PropertiesSetsContent.Property = AdditionalAttributesAndInformation.Ref)
	|					AND (PropertiesSetsContent.Ref IN (&PrListOfSets))
	|		WHERE
	|			AdditionalAttributesAndInformation.Ref IN(&PrLstSelected)
	|			AND (PropertiesSetsContent.Ref IS NULL 
	|					OR AdditionalAttributesAndInformation.ThisIsAdditionalInformation <> &ThisIsAdditionalInformation)) AS Properties
	|		ON AdditionalAttributesAndInformation.Ref = Properties.Property
	|
	|ORDER BY Properties.LineNumber";
	//|RESULTS
	//|	BY Property ONLY HIERARCHY;
	
	Query.SetParameter("ThisIsAdditionalInformation", Not ForAddDetails);
	Query.SetParameter("PrListOfSets", PrListOfSets);
	Query.SetParameter("PrLstSelected", PrLstSelected);
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Tree.Columns.Insert(2, "Value", Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.Type);

	
	NewTree = New ValueTree;
	For Each Column IN Tree.Columns Do
		NewTree.Columns.Add(Column.Name, Column.ValueType);
	EndDo;
	
	CopyStringValuesTree(NewTree.Rows, Tree.Rows, ChartsOfCharacteristicTypes.AdditionalAttributesAndInformation.EmptyRef());
	
	For Each Str IN propertiesTab Do
		StrD = NewTree.Rows.Find(Str.Property, "Property", True);
		If StrD <> Undefined Then
			StrD.Value = Str.Value;
		EndIf;
	EndDo;
	
	Return NewTree;
	
EndFunction // GetTreeForEditPropertiesValues()

// Fill property value tree on the object form.
//
Function FillValuesPropertiesTree(Ref, AdditionalAttributes, ForAdditionalAttributes, Sets) Export
	
	If TypeOf(Sets) = Type("ValueList") Then
		PrListOfSets = Sets;
	Else
		PrListOfSets = New ValueList;
		If Sets <> Undefined Then
			PrListOfSets.Add(Sets);
		EndIf;
	EndIf;
	
	Tree = GetTreeForEditPropertiesValues(PrListOfSets, AdditionalAttributes, ForAdditionalAttributes);
	
	Return Tree;
	
EndFunction // FillValuesPropertiesTree()

// Fill tabular section of propety value object from property value tree on form.
//
Procedure MovePropertiesValues(AdditionalAttributes, PropertyTree) Export
	
	Values = New Map;
	FillPropertyValuesFromTree(PropertyTree.Rows, Values);
	
	AdditionalAttributes.Clear();
	For Each Str IN Values Do
		NewRow = AdditionalAttributes.Add();
		NewRow.Property = Str.Key;
		NewRow.Value = Str.Value;
	EndDo;
	
EndProcedure // MovePropertiesValues()

// Fill the matching by the rows of the property values tree with non-empty values.
//
Procedure FillPropertyValuesFromTree(TreeRows, Values)

	For Each Str IN TreeRows Do
		//If Str.Group
		//	Then FillPropertiesValuesFromTree(Str.Strings, Values);
		//ElsIf ValueIsFilled(Str.Value)
		//	Then Values.Insert(Str.Property, Str.Value);
		//EndIf;
		If ValueIsFilled(Str.Value) Then
			Values.Insert(Str.Property, Str.Value);
		EndIf;
	EndDo;

EndProcedure // FillPropertyValuesFromTree() 

#EndRegion