// Show the graphical stage graph (green check marks) on the job page and on the build page.
import io.jenkins.plugins.pipelinegraphview.PipelineGraphViewConfiguration

def cfg = PipelineGraphViewConfiguration.get()
cfg.setShowGraphOnJobPage(true)
cfg.setShowGraphOnBuildPage(true)
cfg.setShowStageNames(true)
cfg.setShowStageDurations(true)
cfg.save()
