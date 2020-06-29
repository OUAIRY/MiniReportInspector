codeunit 50100 "Report_Management"
{
    procedure ExportReportDataset(ReportIDasIntegerOrText: Variant; ExportToExcel: Boolean)
    var
        ReportID: Integer;
        XMLDoc: XmlDocument;
        RequestPageParams: text;
    begin
        if not TryFindReportID(ReportIDasIntegerOrText, ReportID) then
            Error('Invalid ReportID "%1"', ReportIDasIntegerOrText);
        RequestPageParams := Report.RunRequestPage(ReportID);
        XMLDoc := GetReportDatasetXML(ReportID, RequestPageParams);
        if ExportToExcel then
            ExportDataSetXMLAsExcel(XMLDoc)
        else
            ExportDataSetXML(XMLDoc);
    end;

    procedure TryFindReportID(ReportIDasIntegerOrText: Variant; var ReportID: Integer) Found: boolean
    begin
        if ReportIDasIntegerOrText.IsInteger then
            ReportID := ReportIDasIntegerOrText;
        if ReportIDasIntegerOrText.IsText then
            ReportId := GetNumberFromString(Format(ReportIDasIntegerOrText));
        Found := (ReportID <> 0);
    end;

    procedure ExportDataSetXMLAsExcel(DataSetXML: XmlDocument);
    var
        ExcelBuffer: Record "Excel Buffer" temporary;
        ColumnIndex: Integer;
        RowIndex: Integer;
        AttrNode: XmlAttribute;
        DataSetCols: XmlNodeList;
        ColNode: XmlNode;
        DataSetRows: XmlNodeList;
        RowNode: XmlNode;
        NodeValue: text;
        Name: Text;
    begin
        DataSetXML.SelectNodes('/ReportDataSet/DataItems/DataItem/Columns', DataSetRows);
        for RowIndex := 1 to DataSetRows.Count do begin
            ExcelBuffer.NewRow();
            DataSetRows.Get(RowIndex, RowNode);
            RowNode.SelectNodes('node()', DataSetCols);  // Childnodes
            // Header
            if RowIndex = 1 then
                for ColumnIndex := 1 to DataSetCols.Count do begin
                    DataSetCols.Get(ColumnIndex, ColNode);
                    if ColNode.IsXmlElement() then begin
                        if ColNode.AsXmlElement().Attributes().Get('name', AttrNode) then begin
                            Name := AttrNode.Value();
                            ExcelBuffer.AddColumn(Name, false, '', true, false, false, '', ExcelBuffer."Cell Type"::Text);
                        end;
                        if ColNode.AsXmlElement().Attributes().Get('decimalformatter', AttrNode) then begin
                            NodeValue := AttrNode.Value();
                            ExcelBuffer.AddColumn(Name + '_FORMAT', false, '', true, false, false, '', ExcelBuffer."Cell Type"::Text);
                        end;
                    end;
                    if ColumnIndex = DataSetCols.Count then
                        ExcelBuffer.NewRow();
                end;
            // Lines
            for ColumnIndex := 1 to DataSetCols.Count do begin
                DataSetCols.Get(ColumnIndex, ColNode);
                if ColNode.IsXmlElement then begin
                    NodeValue := ColNode.AsXmlElement().InnerText;
                    ExcelBuffer.AddColumn(NodeValue, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                    if ColNode.AsXmlElement().Attributes().Get('decimalformatter', AttrNode) then begin
                        NodeValue := AttrNode.Value();
                        ExcelBuffer.AddColumn(NodeValue, false, '', false, false, false, '', ExcelBuffer."Cell Type"::Text);
                    end;
                end;
            end;
            ExcelBuffer.CreateNewBook('SheetNameTxt');
            ExcelBuffer.WriteSheet(Format(CurrentDateTime, 0, 9), CompanyName(), UserId());
            ExcelBuffer.CloseBook();
            ExcelBuffer.SetFriendlyFilename('DataSetExport');
            ExcelBuffer.OpenExcel();
        end;
    end;

    procedure ExportDataSetXML(DataSetXML: XmlDocument)
    var
        TempBlob: Codeunit "Temp Blob";
        FileMgt: Codeunit "File Management";
        OutStr: OutStream;
    begin
        TempBlob.CreateOutStream(OutStr);
        DataSetXML.WriteTo(OutStr);
        FileMgt.BLOBExport(TempBlob, 'DataSet.xml', true);
    end;

    procedure GetReportDatasetXML(ReportID: Integer; RequestPageParams: Text) XMLDoc: XmlDocument
    var
        TenantMedia: Record "Tenant Media";
        InStr: InStream;
        OutStr: OutStream;
    begin
        TenantMedia.CalcFields(Content);
        TenantMedia.Content.CreateOutStream(OutStr, TextEncoding::Windows);
        Report.SaveAs(ReportID, RequestPageParams, ReportFormat::Xml, OutStr);
        TenantMedia.Content.CreateInStream(InStr, TextEncoding::Windows);
        XmlDocument.ReadFrom(InStr, XMLDoc);
    end;

    procedure GetNumberFromString(String: Text): integer
    var
        LoopNo: Integer;
        ReportID: Integer;
        ReportName: Text;
        StringPart: Text;
    begin
        for LoopNo := 1 to StrLen(String) do begin
            StringPart := CopyStr(String, LoopNo, 1);
            if StringPart in ['0' .. '9'] then
                reportName += StringPart;
        end;
        Evaluate(ReportID, ReportName);
        exit(ReportID);
    end;
}