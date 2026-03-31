import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  HardDrive,
  FolderOpen,
  Share2,
  Upload as UploadIcon,
  Activity,
  Settings,
  Search,
  Home,
  ChevronRight,
  Folder,
  FileText,
  Image,
  Film,
  Music,
  Archive,
  Download,
  Trash2,
  MoreVertical,
  X,
  Plus,
  Check,
  Copy,
  QrCode,
  ChevronUp,
  ChevronDown,
  FileIcon,
  Calendar,
  Eye,
} from "lucide-react";
import { Card } from "../ui/card";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Progress } from "../ui/progress";
import { Badge } from "../ui/badge";
import { Separator } from "../ui/separator";
import { ScrollArea } from "../ui/scroll-area";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "../ui/dialog";
import { Label } from "../ui/label";
import { Switch } from "../ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../ui/select";
import { toast } from "sonner";

const mockFiles = [
  { name: "Photos", type: "folder", size: "2.4 GB", items: 342, modified: "Mar 10, 2024", icon: "folder" },
  { name: "Documents", type: "folder", size: "456 MB", items: 89, modified: "Mar 09, 2024", icon: "folder" },
  { name: "Videos", type: "folder", size: "12.8 GB", items: 24, modified: "Mar 08, 2024", icon: "folder" },
  { name: "project-report.pdf", type: "PDF Document", size: "2.4 MB", modified: "Mar 12, 2024", icon: "document" },
  { name: "vacation-2024.zip", type: "Archive", size: "145 MB", modified: "Mar 11, 2024", icon: "archive" },
  { name: "presentation.mp4", type: "Video", size: "89 MB", modified: "Mar 10, 2024", icon: "video" },
  { name: "cover-image.png", type: "PNG Image", size: "4.2 MB", modified: "Mar 09, 2024", icon: "image" },
  { name: "budget.xlsx", type: "Spreadsheet", size: "1.2 MB", modified: "Mar 08, 2024", icon: "document" },
];

const mockUploads = [
  { name: "design-assets.zip", size: "245 MB", progress: 67, speed: "12.4 MB/s", status: "uploading" },
  { name: "video-tutorial.mp4", size: "890 MB", progress: 34, speed: "8.2 MB/s", status: "uploading" },
];

type SortField = "name" | "size" | "type" | "modified";

export function WebConsole() {
  const [searchQuery, setSearchQuery] = useState("");
  const [showUploadDialog, setShowUploadDialog] = useState(false);
  const [showShareDialog, setShowShareDialog] = useState(false);
  const [selectedFile, setSelectedFile] = useState<string | null>("project-report.pdf");
  const [showUploadPanel, setShowUploadPanel] = useState(true);
  const [sortField, setSortField] = useState<SortField>("name");
  const [sortAsc, setSortAsc] = useState(true);

  const getFileIcon = (icon: string) => {
    switch (icon) {
      case "folder":
        return <Folder className="w-4 h-4 text-primary" />;
      case "document":
        return <FileText className="w-4 h-4 text-accent" />;
      case "image":
        return <Image className="w-4 h-4 text-highlight" />;
      case "video":
        return <Film className="w-4 h-4 text-[#F59E0B]" />;
      case "audio":
        return <Music className="w-4 h-4 text-accent" />;
      case "archive":
        return <Archive className="w-4 h-4 text-muted-foreground" />;
      default:
        return <FileText className="w-4 h-4 text-muted-foreground" />;
    }
  };

  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortAsc(!sortAsc);
    } else {
      setSortField(field);
      setSortAsc(true);
    }
  };

  const SortIndicator = ({ field }: { field: SortField }) => {
    if (sortField !== field) return null;
    return sortAsc ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />;
  };

  const copyShareLink = () => {
    navigator.clipboard.writeText("https://easy-cloud-x7k9m.relay.io/share/abc123def456");
    toast.success("Share link copied to clipboard");
  };

  const selectedFileData = mockFiles.find(f => f.name === selectedFile);

  return (
    <div className="h-screen bg-background flex flex-col">
      {/* Three-Pane Finder Layout */}
      <div className="flex-1 flex overflow-hidden">
        {/* Sidebar */}
        <div className="w-56 bg-card border-r border-border flex flex-col shadow-sm">
          <div className="px-4 py-3.5 border-b border-border">
            <div className="flex items-center gap-2.5">
              <div className="p-1.5 bg-primary/10 rounded-lg">
                <HardDrive className="w-4 h-4 text-primary" />
              </div>
              <div>
                <h2 className="text-sm font-semibold text-foreground">Easy Cloud</h2>
                <p className="text-xs text-muted-foreground font-mono">x7k9m</p>
              </div>
            </div>
          </div>

          <ScrollArea className="flex-1 px-2 py-3">
            <div className="space-y-0.5">
              <Button
                variant="secondary"
                className="w-full justify-start gap-2.5 h-8 text-sm font-normal"
              >
                <FolderOpen className="w-4 h-4" />
                Drive
              </Button>
              <Button variant="ghost" className="w-full justify-start gap-2.5 h-8 text-sm font-normal">
                <Share2 className="w-4 h-4" />
                Shared Links
              </Button>
              <Button variant="ghost" className="w-full justify-start gap-2.5 h-8 text-sm font-normal">
                <UploadIcon className="w-4 h-4" />
                Uploads
                {mockUploads.length > 0 && (
                  <Badge className="ml-auto bg-primary/20 text-primary border-primary/30 text-xs px-1.5 py-0">
                    {mockUploads.length}
                  </Badge>
                )}
              </Button>
              <Button variant="ghost" className="w-full justify-start gap-2.5 h-8 text-sm font-normal">
                <Activity className="w-4 h-4" />
                Activity
              </Button>
            </div>

            <div className="h-px bg-border my-3"></div>

            <div className="px-2 mb-2">
              <h4 className="text-xs font-medium text-muted-foreground">Storage</h4>
            </div>
            <div className="px-2">
              <div className="p-2.5 bg-primary/5 rounded-lg border border-primary/20">
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs text-muted-foreground">Used</span>
                  <span className="text-xs font-mono text-foreground">245 / 512 GB</span>
                </div>
                <Progress value={47.85} className="h-1 mb-1.5" />
                <div className="text-xs text-muted-foreground">47.85% full</div>
              </div>
            </div>
          </ScrollArea>

          <div className="p-3 border-t border-border">
            <Button variant="ghost" className="w-full justify-start gap-2.5 h-8 text-sm font-normal" size="sm">
              <Settings className="w-4 h-4" />
              Settings
            </Button>
          </div>
        </div>

        {/* File List */}
        <div className="flex-1 flex flex-col border-r border-border bg-background">
          {/* Toolbar */}
          <div className="h-14 border-b border-border bg-card/50 flex items-center justify-between px-4 shadow-sm">
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <Home className="w-3.5 h-3.5" />
                <ChevronRight className="w-3 h-3" />
                <span className="text-foreground font-mono">Root</span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <div className="relative w-64">
                <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-muted-foreground" />
                <Input
                  placeholder="Search files..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-8 h-8 text-sm bg-background/50 border-border"
                />
              </div>

              <Button onClick={() => setShowUploadDialog(true)} className="gap-2 bg-primary h-8 text-sm" size="sm">
                <UploadIcon className="w-3.5 h-3.5" />
                Upload
              </Button>
              <Button variant="outline" className="gap-2 h-8 text-sm" size="sm">
                <Plus className="w-3.5 h-3.5" />
                New Folder
              </Button>
            </div>
          </div>

          {/* Column Headers */}
          <div className="h-9 bg-card/30 border-b border-border flex items-center px-4 text-xs font-medium text-muted-foreground">
            <button
              onClick={() => handleSort("name")}
              className="flex items-center gap-1 hover:text-foreground transition-colors flex-1"
            >
              Name
              <SortIndicator field="name" />
            </button>
            <button
              onClick={() => handleSort("modified")}
              className="flex items-center gap-1 hover:text-foreground transition-colors w-36"
            >
              Date Modified
              <SortIndicator field="modified" />
            </button>
            <button
              onClick={() => handleSort("type")}
              className="flex items-center gap-1 hover:text-foreground transition-colors w-32"
            >
              Type
              <SortIndicator field="type" />
            </button>
            <button
              onClick={() => handleSort("size")}
              className="flex items-center gap-1 hover:text-foreground transition-colors w-24"
            >
              Size
              <SortIndicator field="size" />
            </button>
            <div className="w-24"></div>
          </div>

          {/* File Rows */}
          <ScrollArea className="flex-1">
            <div className="divide-y divide-border/50">
              {mockFiles.map((file, index) => (
                <motion.button
                  key={file.name}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ delay: index * 0.02 }}
                  onClick={() => setSelectedFile(file.name)}
                  className={`w-full flex items-center px-4 py-2 text-left hover:bg-card/50 transition-colors ${
                    selectedFile === file.name ? "bg-primary/10" : ""
                  }`}
                >
                  <div className="flex items-center gap-2.5 flex-1 min-w-0">
                    {getFileIcon(file.icon)}
                    <span className="text-sm text-foreground truncate">{file.name}</span>
                  </div>
                  <div className="w-36 text-xs text-muted-foreground">{file.modified}</div>
                  <div className="w-32 text-xs text-muted-foreground">{file.type}</div>
                  <div className="w-24 text-xs font-mono text-muted-foreground">{file.size}</div>
                  <div className="w-24 flex items-center justify-end gap-1">
                    <Button variant="ghost" size="icon" className="h-7 w-7" onClick={(e) => { e.stopPropagation(); setShowShareDialog(true); }}>
                      <Share2 className="w-3.5 h-3.5" />
                    </Button>
                    <Button variant="ghost" size="icon" className="h-7 w-7">
                      <MoreVertical className="w-3.5 h-3.5" />
                    </Button>
                  </div>
                </motion.button>
              ))}
            </div>
          </ScrollArea>
        </div>

        {/* Preview Panel */}
        <div className="w-72 bg-card border-l border-border flex flex-col shadow-sm">
          <div className="px-4 py-3.5 border-b border-border">
            <h3 className="text-sm font-semibold text-foreground">Preview</h3>
          </div>

          {selectedFileData ? (
            <ScrollArea className="flex-1 p-4">
              <div className="space-y-4">
                {/* Preview Image Placeholder */}
                <div className="aspect-square bg-background rounded-lg border border-border flex items-center justify-center">
                  {getFileIcon(selectedFileData.icon)}
                </div>

                {/* File Details */}
                <div className="space-y-3">
                  <div>
                    <h4 className="text-sm font-medium text-foreground mb-1 truncate">
                      {selectedFileData.name}
                    </h4>
                    <p className="text-xs text-muted-foreground">{selectedFileData.type}</p>
                  </div>

                  <div className="h-px bg-border"></div>

                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-muted-foreground">Size</span>
                      <span className="text-xs font-mono text-foreground">{selectedFileData.size}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-muted-foreground">Modified</span>
                      <span className="text-xs text-foreground">{selectedFileData.modified}</span>
                    </div>
                    {selectedFileData.items && (
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-muted-foreground">Items</span>
                        <span className="text-xs text-foreground">{selectedFileData.items}</span>
                      </div>
                    )}
                  </div>

                  <div className="h-px bg-border"></div>

                  <div className="space-y-2">
                    <Button variant="outline" size="sm" className="w-full justify-start gap-2 h-8 text-xs">
                      <Download className="w-3.5 h-3.5" />
                      Download
                    </Button>
                    <Button variant="outline" size="sm" className="w-full justify-start gap-2 h-8 text-xs" onClick={() => setShowShareDialog(true)}>
                      <Share2 className="w-3.5 h-3.5" />
                      Share
                    </Button>
                    <Button variant="outline" size="sm" className="w-full justify-start gap-2 h-8 text-xs text-destructive border-destructive/30 hover:bg-destructive/10">
                      <Trash2 className="w-3.5 h-3.5" />
                      Delete
                    </Button>
                  </div>
                </div>
              </div>
            </ScrollArea>
          ) : (
            <div className="flex-1 flex items-center justify-center p-4 text-center">
              <div>
                <Eye className="w-8 h-8 text-muted-foreground mx-auto mb-2" />
                <p className="text-xs text-muted-foreground">Select a file to preview</p>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Upload Panel (Bottom) */}
      <AnimatePresence>
        {showUploadPanel && mockUploads.length > 0 && (
          <motion.div
            initial={{ height: 0 }}
            animate={{ height: "auto" }}
            exit={{ height: 0 }}
            className="border-t border-border bg-card shadow-lg overflow-hidden"
          >
            <div className="px-4 py-2.5 flex items-center justify-between border-b border-border">
              <div className="flex items-center gap-2">
                <UploadIcon className="w-4 h-4 text-primary" />
                <h3 className="text-sm font-medium text-foreground">
                  Uploading {mockUploads.length} {mockUploads.length === 1 ? "file" : "files"}
                </h3>
              </div>
              <Button variant="ghost" size="icon" className="h-6 w-6" onClick={() => setShowUploadPanel(false)}>
                <X className="w-3.5 h-3.5" />
              </Button>
            </div>
            <div className="px-4 py-3 space-y-2 max-h-48 overflow-y-auto">
              {mockUploads.map((upload, index) => (
                <div key={upload.name} className="flex items-center gap-3">
                  <div className="p-1.5 bg-primary/10 rounded">
                    <UploadIcon className="w-3.5 h-3.5 text-primary" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs font-medium text-foreground truncate">{upload.name}</span>
                      <span className="text-xs text-muted-foreground font-mono ml-2">{upload.progress}%</span>
                    </div>
                    <Progress value={upload.progress} className="h-1" />
                    <div className="flex items-center justify-between mt-1">
                      <span className="text-xs text-muted-foreground">{upload.speed}</span>
                      <span className="text-xs text-muted-foreground font-mono">{upload.size}</span>
                    </div>
                  </div>
                  <Button variant="ghost" size="icon" className="h-6 w-6 shrink-0">
                    <X className="w-3.5 h-3.5" />
                  </Button>
                </div>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Upload Dialog */}
      <Dialog open={showUploadDialog} onOpenChange={setShowUploadDialog}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="text-base">Upload Files</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="border-2 border-dashed border-border rounded-lg p-8 text-center hover:bg-card/50 transition-colors cursor-pointer">
              <UploadIcon className="w-10 h-10 text-muted-foreground mx-auto mb-3" />
              <div className="text-sm text-foreground mb-1">
                Drop files here or click to browse
              </div>
              <div className="text-xs text-muted-foreground">
                Maximum file size: 2GB
              </div>
            </div>
            <div className="flex gap-2">
              <Button className="flex-1 bg-primary h-9 text-sm">Select Files</Button>
              <Button variant="outline" className="flex-1 h-9 text-sm" onClick={() => setShowUploadDialog(false)}>
                Cancel
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Share Dialog */}
      <Dialog open={showShareDialog} onOpenChange={setShowShareDialog}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle className="text-base">Share File</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label className="text-xs text-muted-foreground mb-2 block">Share Link</Label>
              <div className="flex gap-2">
                <Input
                  value="https://easy-cloud-x7k9m.relay.io/share/abc123def456"
                  readOnly
                  className="font-mono text-xs bg-background/50 h-9"
                />
                <Button variant="outline" size="icon" onClick={copyShareLink} className="h-9 w-9">
                  <Copy className="w-3.5 h-3.5" />
                </Button>
              </div>
            </div>

            <div className="h-px bg-border"></div>

            <div className="flex items-center justify-between">
              <div>
                <Label className="text-sm text-foreground">Password Protection</Label>
                <p className="text-xs text-muted-foreground mt-0.5">Require password to access</p>
              </div>
              <Switch />
            </div>

            <div>
              <Label className="text-xs text-muted-foreground mb-2 block">Link Expiration</Label>
              <Select defaultValue="never">
                <SelectTrigger className="h-9 text-sm">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="never">Never</SelectItem>
                  <SelectItem value="1h">1 Hour</SelectItem>
                  <SelectItem value="24h">24 Hours</SelectItem>
                  <SelectItem value="7d">7 Days</SelectItem>
                  <SelectItem value="30d">30 Days</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="h-px bg-border"></div>

            <div className="flex gap-2">
              <Button className="flex-1 bg-primary h-9 text-sm" onClick={copyShareLink}>
                <Copy className="w-3.5 h-3.5 mr-2" />
                Copy Link
              </Button>
              <Button variant="outline" className="gap-2 h-9 text-sm">
                <QrCode className="w-3.5 h-3.5" />
                QR Code
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
