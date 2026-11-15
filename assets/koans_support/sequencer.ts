import { BaseSequencer, type TestSpecification } from "vitest/node"

export class PathSequencer extends BaseSequencer {
  override async sort(files: TestSpecification[]): Promise<TestSpecification[]> {
    return [...files].sort((a, b) =>
      a.moduleId < b.moduleId ? -1 : a.moduleId > b.moduleId ? 1 : 0,
    )
  }
}
