////////////////////////////////////////////////////////////////////////////////
// Subsystem "Data export import".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Return metadata objects, separated with delimiter with
//  separation data type "Independently and jointly".
//
// Return value: FixedStructure:
//                         * Key - a row,
//                         name of a separator, * Value - FixedStructure:
//                            * Constants - Array(Row) - an array of constants full
//                            names, separated with delimiter, * Objects - Array(Row) - an array of objects full
//                            names, separated with delimiter, * RecordSets - Array(Row) - an array of full names record sets, separated with delimiter.
//
Function JointlySeparatedMetadataObjects() Export
	
	Cache = New Structure();
	
	Separators = SeparatorsWithIndependentlyAndJointlyDivisionType();
	
	For Each Delimiter IN Separators Do
		
		SeparatedObjectsStructure = New Structure("Constants,Objects,RecordSets", New Array(), New Array(), New Array());
		
		AutoUse = (Delimiter.AutoUse = Metadata.ObjectProperties.CommonAttributeAutoUse.Use);
		
		For Each ContentItem IN Delimiter.Content Do
			
			If ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Use
					OR (AutoUse AND ContentItem.Use = Metadata.ObjectProperties.CommonAttributeUse.Auto) Then
				
				If CommonUseSTL.ThisIsConstant(ContentItem.Metadata) Then
					SeparatedObjectsStructure.Constants.Add(ContentItem.Metadata.FullName());
				ElsIf CommonUseSTL.ThisIsReferenceData(ContentItem.Metadata) Then
					SeparatedObjectsStructure.Objects.Add(ContentItem.Metadata.FullName());
				ElsIf CommonUseSTL.ThisIsRecordSet(ContentItem.Metadata) Then
					SeparatedObjectsStructure.RecordSets.Add(ContentItem.Metadata.FullName());
				EndIf;
				
			EndIf;
			
			Cache.Insert(Delimiter.Name, New FixedStructure(SeparatedObjectsStructure));
			
		EndDo;
		
	EndDo;
	
	Return New FixedStructure(Cache);
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function SeparatorsWithIndependentlyAndJointlyDivisionType()
	
	Result = New Array();
	
	For Each CommonAttribute IN Metadata.CommonAttributes Do
		
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate
				AND CommonAttribute.UseSharedData = Metadata.ObjectProperties.UseSharedDataCommonAttribute.IndependentlyAndJointly Then
			
			Result.Add(CommonAttribute);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion