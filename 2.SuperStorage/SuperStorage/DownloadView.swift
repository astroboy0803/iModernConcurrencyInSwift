import SwiftUI
import UIKit

struct DownloadView: View {
    let file: DownloadFile
    @EnvironmentObject var model: SuperStorageModel
    @State var fileData: Data?
    @State var isDownloadActive = false
    var body: some View {
        List {
            FileDetails(
                file: file,
                isDownloading: !model.downloads.isEmpty,
                isDownloadActive: $isDownloadActive,
                downloadSingleAction: {
                    isDownloadActive = true
                    Task {
                        do {
                            fileData = try await model.download(file: file)
                        } catch {
                            
                        }
                        isDownloadActive = false
                    }                    
                },
                downloadWithUpdatesAction: {
                },
                downloadMultipleAction: {
                }
            )
            if !model.downloads.isEmpty {
                Downloads(downloads: model.downloads)
            }
            if let fileData = fileData {
                FilePreview(fileData: fileData)
            }
        }
        .animation(.easeOut(duration: 0.33), value: model.downloads)
        .listStyle(InsetGroupedListStyle())
        .toolbar(content: {
            Button(action: {
            }, label: { Text("Cancel All") })
            .disabled(model.downloads.isEmpty)
        })
        .onDisappear {
            fileData = nil
            model.reset()
        }
    }
}
